import 'dart:io';

import '../models/models.dart';
import 'system_command.dart';

part 'magic_dns_android.dart';
part 'magic_dns_android_rules.dart';
part 'magic_dns_facts.dart';
part 'magic_dns_platform.dart';

/// The address EasyTier Magic DNS answers from inside the tunnel.
const magicDnsServer = '100.100.100.101';

/// The system DNS side of EasyTier Magic DNS.
///
/// Windows (NRPT) and Linux (`systemd-resolved` over D-Bus) are configured
/// natively by EasyTier, and Android app mode uses `VpnService`. The Android
/// root service redirects the zone's own lookups into the tunnel instead; see
/// `MagicDnsAndroid`.
final class MagicDnsSystem {
  MagicDnsSystem({MagicDnsPlatform? platform, SystemCommand? command})
    : platform = platform ?? _runningPlatform(),
      _command = command ?? const ProcessSystemCommand();

  /// The platform whose system DNS this helper configures.
  final MagicDnsPlatform platform;
  final SystemCommand _command;

  /// Whether this process configures the host's system DNS.
  bool get supported => platform == MagicDnsPlatform.android;

  static final _interface = RegExp(r'^[A-Za-z0-9_.-]+$');
  static final _link = RegExp(r'^\d+:\s+([^\s:]+)', multiLine: true);

  /// Whether the system DNS sends [zone] to the Magic DNS server, and the
  /// EasyTier interface the probe found.
  ///
  /// [interfaceName] is the network's configured TUN name and [address] its
  /// virtual IPv4; together they name the interface the system DNS has to be
  /// set on, or none when the EasyTier link cannot be identified yet.
  Future<MagicDnsProbe> probe({
    required String zone,
    required String interfaceName,
    String? address,
  }) async {
    if (!supported) {
      return (state: MagicDnsState.unsupported, interface: null);
    }
    return _probeAndroid(
      zone: zone,
      interfaceName: interfaceName,
      address: address,
    );
  }

  /// Sends [zone]'s lookups to the Magic DNS server on the Android root service.
  Future<void> apply({
    required String zone,
    required String interfaceName,
    String? address,
  }) async {
    if (!supported) return;
    return _applyAndroid(zone: zone);
  }

  /// Gives the system DNS back the configuration it had before [apply].
  Future<void> reset({required String interfaceName, String? zone}) async {
    if (!supported) return;
    return _resetAndroid(zone: zone);
  }

  /// The EasyTier interface of one network: the configured TUN name when that
  /// link is up, else the link that owns the network's virtual IPv4.
  ///
  /// The route to [magicDnsServer] is deliberately not consulted: another
  /// VPN's TUN can own it, and its DNS is not this network's to change. Null
  /// when neither name identifies a link, so a caller fails closed instead.
  Future<String?> _findInterface(String configuredName, String? address) async {
    if (configuredName.isNotEmpty) {
      final link = await _try('ip', ['link', 'show', configuredName]);
      if (link != null && link.exitCode == 0) return configuredName;
    }
    final host = magicDnsIpv4Host(address);
    if (host == null) return null;
    final owned = await _try('ip', ['-4', '-o', 'addr', 'show', 'to', host]);
    if (owned == null || owned.exitCode != 0) return null;
    final name = _link.firstMatch(owned.stdout)?.group(1);
    return name != null && _interface.hasMatch(name) ? name : null;
  }

  Future<CommandResult?> _try(String executable, List<String> arguments) async {
    try {
      return await _command.run(executable, arguments);
    } on ProcessException {
      return null;
    }
  }
}

import 'dart:io';

import '../models/models.dart';
import 'system_command.dart';

part 'magic_dns_android.dart';
part 'magic_dns_android_rules.dart';
part 'magic_dns_facts.dart';
part 'magic_dns_manual.dart';
part 'magic_dns_platform.dart';

/// The address EasyTier Magic DNS answers from inside the tunnel.
const magicDnsServer = '100.100.100.101';

/// The zone EasyTier uses when the network does not name one.
const magicDnsDefaultZone = 'et.net.';

/// The system DNS side of EasyTier Magic DNS.
///
/// Windows lets EasyTier set the DNS servers of its own interface, so it is
/// only read here. Linux has no such setup in EasyTier and is configured
/// through systemd-resolved's `resolvectl`, with administrator rights. The
/// Android root service redirects the zone's own lookups into the tunnel
/// instead; see `MagicDnsAndroid`.
final class MagicDnsSystem {
  MagicDnsSystem({MagicDnsPlatform? platform, SystemCommand? command})
    : platform = platform ?? _runningPlatform(),
      _command = command ?? const ProcessSystemCommand();

  /// The platform whose system DNS this helper shows.
  final MagicDnsPlatform platform;
  final SystemCommand _command;

  /// Whether EasyTier configures this platform's system DNS itself.
  bool get automatic => platform == MagicDnsPlatform.windows;

  /// Whether this process configures this platform's system DNS: the app on
  /// Linux, the root service on Android.
  bool get configurable =>
      platform == MagicDnsPlatform.linux ||
      platform == MagicDnsPlatform.android;

  /// Whether this platform has any system DNS support to show.
  bool get supported => platform != MagicDnsPlatform.other;

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
    if (automatic) return _probeWindows();
    if (platform == MagicDnsPlatform.android) {
      return _probeAndroid(
        zone: zone,
        interfaceName: interfaceName,
        address: address,
      );
    }
    final interface = await _findInterface(interfaceName, address);
    if (interface == null) {
      return (state: MagicDnsState.noInterface, interface: null);
    }
    final dns = await _try('resolvectl', ['dns', interface]);
    final domain = await _try('resolvectl', ['domain', interface]);
    // No resolvectl, or no systemd-resolved answering it: only hand-written
    // configuration is left.
    if (dns == null || domain == null) {
      return (state: MagicDnsState.unsupported, interface: interface);
    }
    // A routing domain is what sends the zone to this link only.
    final configured =
        dns.exitCode == 0 &&
        domain.exitCode == 0 &&
        dns.stdout.contains(magicDnsServer) &&
        domain.stdout.contains('~${magicDnsZoneBase(zone)}');
    return (
      state: configured ? MagicDnsState.configured : MagicDnsState.missing,
      interface: interface,
    );
  }

  /// Sends [zone]'s lookups to the Magic DNS server on the network's own link.
  ///
  /// Linux resolves the interface from [interfaceName] and [address] through
  /// the same helper [probe] uses, so both agree on the link this network
  /// owns, and points that link at the server through systemd-resolved, asking
  /// to elevate once: both values are validated and quoted, because one shell
  /// runs both commands so the user authorizes once. Android installs its
  /// redirect chain, which needs no interface.
  ///
  /// Nothing is applied when no EasyTier interface is identified: a fail-closed
  /// setup leaves another VPN's link alone.
  Future<void> apply({
    required String zone,
    required String interfaceName,
    String? address,
  }) async {
    if (platform == MagicDnsPlatform.android) return _applyAndroid(zone: zone);
    final base = _checked(magicDnsZoneBase(zone), _zoneName, 'zone');
    if (interfaceName.isNotEmpty) {
      _checked(interfaceName, _interface, 'interfaceName');
    }
    final name = await _findInterface(interfaceName, address);
    if (name == null) return;
    await _command.runElevated('sh', [
      '-c',
      'resolvectl dns ${_quote(name)} $magicDnsServer && '
          'resolvectl domain ${_quote(name)} ${_quote('~$base')}',
    ]);
  }

  /// Gives the system DNS back the configuration it had before [apply].
  ///
  /// [zone] names the configuration on platforms that serve several zones at
  /// once; Linux reverts [interfaceName] as a whole and ignores it.
  Future<void> reset({required String interfaceName, String? zone}) async {
    if (platform == MagicDnsPlatform.android) return _resetAndroid(zone: zone);
    final name = _checked(interfaceName, _interface, 'interfaceName');
    await _command.runElevated('resolvectl', ['revert', name]);
  }

  /// Windows lists every interface's DNS servers in `ipconfig /all`, which
  /// needs no elevation; EasyTier writes their own, so nothing is written
  /// here.
  Future<MagicDnsProbe> _probeWindows() async {
    final ipconfig = await _try('ipconfig', ['/all']);
    final configured =
        ipconfig != null &&
        ipconfig.exitCode == 0 &&
        ipconfig.stdout.contains(magicDnsServer);
    return (
      state: configured ? MagicDnsState.configured : MagicDnsState.missing,
      interface: null,
    );
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

  static String _checked(String value, RegExp pattern, String name) {
    if (!pattern.hasMatch(value)) {
      throw ArgumentError.value(value, name, 'unsafe for a system command');
    }
    return value;
  }

  /// Single-quotes [value] for the one shell command that runs two tools.
  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}

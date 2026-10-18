import 'dart:io';

import 'system_command.dart';

part 'magic_dns_manual.dart';

/// The address EasyTier Magic DNS answers from inside the tunnel.
const magicDnsServer = '100.100.100.101';

/// The zone EasyTier uses when the network does not name one.
const magicDnsDefaultZone = 'et.net.';

/// The platforms Yukari ships on, as far as the system DNS setup goes.
enum MagicDnsPlatform {
  /// The app points systemd-resolved at the EasyTier interface.
  linux,

  /// EasyTier writes the DNS servers of its own TUN interface itself.
  windows,

  /// No supported system DNS setup; the helper stays hidden.
  other,
}

/// The [MagicDnsPlatform] of the running system.
MagicDnsPlatform _runningPlatform() {
  if (Platform.isLinux) return MagicDnsPlatform.linux;
  if (Platform.isWindows) return MagicDnsPlatform.windows;
  return MagicDnsPlatform.other;
}

/// Everything the Magic DNS helper shows.
///
/// [off] and [notRunning] are the network's state, added by the controller;
/// [MagicDnsSystem.probe] reports the others.
enum MagicDnsState {
  /// Magic DNS is off for this network.
  off,

  /// Magic DNS is on, but the network is not running.
  notRunning,

  /// No systemd-resolved: DNS has to be configured by hand.
  unsupported,

  /// No EasyTier interface yet: the network is not running, or still starting.
  noInterface,

  /// The system DNS does not send the zone to the Magic DNS server.
  missing,

  /// The system DNS sends the zone to the Magic DNS server.
  configured,

  /// The last probe or elevated command failed; the error says why.
  failed,
}

/// One look at the system DNS, with the EasyTier interface found on the way.
typedef MagicDnsProbe = ({MagicDnsState state, String? interface});

/// [zone] without its trailing dot, as DNS tools spell it.
String magicDnsZoneBase(String zone) {
  final trimmed = zone.trim();
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// The Magic DNS name of [host] under [zone], such as `laptop.et.net`.
String magicDnsNameOf({required String host, required String zone}) =>
    '$host.${magicDnsZoneBase(zone)}';

/// The system DNS side of EasyTier Magic DNS.
///
/// Windows lets EasyTier set the DNS servers of its own interface, so it is
/// only read here. Linux has no such setup in EasyTier and is configured
/// through systemd-resolved's `resolvectl`, with administrator rights.
final class MagicDnsSystem {
  MagicDnsSystem({MagicDnsPlatform? platform, SystemCommand? command})
    : platform = platform ?? _runningPlatform(),
      _command = command ?? const ProcessSystemCommand();

  /// The platform whose system DNS this helper shows.
  final MagicDnsPlatform platform;
  final SystemCommand _command;

  /// Whether EasyTier configures this platform's system DNS itself.
  bool get automatic => platform == MagicDnsPlatform.windows;

  /// Whether the app configures this platform's system DNS.
  bool get configurable => platform == MagicDnsPlatform.linux;

  /// Whether this platform has any system DNS support to show.
  bool get supported => platform != MagicDnsPlatform.other;

  static final _dev = RegExp(r'\bdev\s+(\S+)');
  static final _zoneBase = RegExp(
    r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$',
  );
  static final _interface = RegExp(r'^[A-Za-z0-9_.-]+$');

  /// Whether the system DNS sends [zone] to the Magic DNS server, and the
  /// EasyTier interface the probe found.
  ///
  /// [interfaceName] is the network's configured TUN name, used when the route
  /// to the Magic DNS server is not there yet.
  Future<MagicDnsProbe> probe({
    required String zone,
    required String interfaceName,
  }) async {
    if (!supported) {
      return (state: MagicDnsState.unsupported, interface: null);
    }
    if (automatic) return _probeWindows();
    final interface = await _findInterface(interfaceName);
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

  /// Points [interfaceName]'s DNS at the Magic DNS server, with [zone] routed
  /// only to it, asking to elevate once.
  ///
  /// Both values are validated and quoted, because one shell runs both
  /// commands so the user authorizes once.
  Future<void> apply({
    required String zone,
    required String interfaceName,
  }) async {
    final base = _checked(magicDnsZoneBase(zone), _zoneBase, 'zone');
    final name = _checked(interfaceName, _interface, 'interfaceName');
    await _command.runElevated('sh', [
      '-c',
      'resolvectl dns ${_quote(name)} $magicDnsServer && '
          'resolvectl domain ${_quote(name)} ${_quote('~$base')}',
    ]);
  }

  /// Gives [interfaceName] back the DNS configuration it had before [apply].
  Future<void> reset({required String interfaceName}) async {
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

  /// The EasyTier interface: the route to the Magic DNS server, else the
  /// configured TUN name when that still exists.
  Future<String?> _findInterface(String configuredName) async {
    final route = await _try('ip', ['-4', 'route', 'get', magicDnsServer]);
    final name = _dev.firstMatch(route?.stdout ?? '')?.group(1);
    if (name != null) return name;
    if (configuredName.isEmpty) return null;
    final link = await _try('ip', ['link', 'show', configuredName]);
    return link != null && link.exitCode == 0 ? configuredName : null;
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

import 'dart:io';

import '../../models/backend.dart';
import 'service_bundle.dart';
import 'system_service.dart';

/// The service as a systemd unit.
///
/// The unit runs a copy of the service in `/opt/yukari/service`, which only
/// root writes, rather than the app's own file; see [stageBundle].
final class SystemdService extends SystemService {
  SystemdService({this.root = defaultRoot});

  static const unitPath = '/etc/systemd/system/${SystemService.name}.service';
  static const defaultRoot = '/opt/yukari/service';
  static const _unit = '${SystemService.name}.service';

  /// Whether [name] is the EasyTier library the service loads from `lib`.
  ///
  /// A local build names it `libeasytier_ffi.so`, a prebuilt download
  /// `linux-<arch>-libeasytier_ffi.so`. The app keeps its own Flutter
  /// libraries in `lib` too, which the copy has no use for.
  static bool _isServiceLibrary(String name) =>
      name.endsWith('libeasytier_ffi.so');

  /// Where the copy the unit runs lives.
  final String root;

  @override
  Future<String> prepare(String executable) =>
      stageBundle(executable, root, library: _isServiceLibrary);

  @override
  Future<ServiceState> state() async {
    if (!await File(unitPath).exists()) return ServiceState.notInstalled;
    final active = await Process.run('systemctl', [
      'is-active',
      '--quiet',
      _unit,
    ]);
    return active.exitCode == 0 ? ServiceState.running : ServiceState.stopped;
  }

  @override
  Future<void> install(String executable, List<String> arguments) async {
    await File(unitPath).writeAsString(unit(executable, arguments));
    await _systemctl(['daemon-reload']);
    await _systemctl(['enable', _unit]);
    await _systemctl(['restart', _unit]);
  }

  @override
  Future<void> uninstall() async {
    if (await File(unitPath).exists()) {
      await _systemctl(['disable', '--now', _unit]);
      await File(unitPath).delete();
      await _systemctl(['daemon-reload']);
    }
    await removeBundle(root);
  }

  @override
  Future<void> start() => _systemctl(['start', _unit]);

  @override
  Future<void> stop() => _systemctl(['stop', _unit]);

  /// The unit that runs [executable] with [arguments] as root on boot.
  ///
  /// Root keeps only what EasyTier needs: TUN devices, routes and sockets,
  /// network namespaces, reading the user's networks and handing the socket
  /// over to them. The rest of the system stays read-only to it.
  static String unit(String executable, List<String> arguments) =>
      '''
[Unit]
Description=Yukari network service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${[executable, ...arguments].map(_quote).join(' ')}
Restart=on-failure
RestartSec=2
RuntimeDirectory=${SystemService.name}
UMask=0077
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_ADMIN CAP_DAC_READ_SEARCH CAP_CHOWN
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=yes
DevicePolicy=closed
DeviceAllow=/dev/net/tun rw
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
RestrictNamespaces=net
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK AF_PACKET
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
''';

  /// Quotes [argument] for ExecStart, which expands `%` and `$` even inside
  /// quotes.
  static String _quote(String argument) {
    final escaped = argument
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('%', '%%')
        .replaceAll(r'$', r'$$');
    return '"$escaped"';
  }

  static Future<void> _systemctl(List<String> arguments) async {
    final result = await Process.run('systemctl', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'systemctl',
        arguments,
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }
}

import 'dart:io';

import '../../models/backend.dart';
import 'system_service.dart';

/// The service as a systemd unit.
final class SystemdService extends SystemService {
  static const unitPath = '/etc/systemd/system/${SystemService.name}.service';
  static const _unit = '${SystemService.name}.service';

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
    if (!await File(unitPath).exists()) return;
    await _systemctl(['disable', '--now', _unit]);
    await File(unitPath).delete();
    await _systemctl(['daemon-reload']);
  }

  @override
  Future<void> start() => _systemctl(['start', _unit]);

  @override
  Future<void> stop() => _systemctl(['stop', _unit]);

  /// The unit that runs [executable] with [arguments] as root on boot.
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

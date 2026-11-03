import 'dart:io';

import 'package:path/path.dart' as p;

import 'autostart.dart';

/// Launches Yukari at sign-in through the XDG autostart directory.
final class LinuxAutostart implements Autostart {
  /// Uses [environment] to resolve the XDG directory and launches [executable].
  /// Both default to the running process's values.
  LinuxAutostart({Map<String, String>? environment, String? executable})
    : _configHome = _defaultConfigHome(environment ?? Platform.environment),
      _executable = executable ?? Platform.resolvedExecutable;

  final String? _configHome;
  final String _executable;

  static String? _defaultConfigHome(Map<String, String> environment) {
    final xdg = environment['XDG_CONFIG_HOME'] ?? '';
    if (p.posix.isAbsolute(xdg)) return xdg;
    final home = environment['HOME'] ?? '';
    return p.posix.isAbsolute(home) ? p.join(home, '.config') : null;
  }

  @override
  bool get supported => _configHome != null;

  @override
  Future<void> setEnabled(bool enabled) async {
    final configHome = _configHome;
    if (configHome == null) return;
    final entry = File(p.join(configHome, 'autostart', 'yukari.desktop'));
    if (!enabled) {
      if (await entry.exists()) await entry.delete();
      return;
    }
    await entry.parent.create(recursive: true);
    await entry.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Yukari\n'
      'Exec=$_execCommand\n'
      'Terminal=false\n'
      'X-GNOME-Autostart-enabled=true\n',
    );
  }

  String get _execCommand {
    // Exec quoting is decoded after desktop-entry string escapes.
    final quoted = _executable.replaceAllMapped(
      RegExp(r'["`$\\]'),
      (match) => '\\${match[0]}',
    );
    final escaped = quoted
        .replaceAll('\\', r'\\')
        .replaceAll('%', '%%')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }
}

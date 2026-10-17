import 'dart:io';

import 'package:path/path.dart' as p;

import 'autostart.dart';

/// Launches Yukari at sign-in through the XDG autostart directory.
final class LinuxAutostart implements Autostart {
  LinuxAutostart({String? configHome, String? executable})
    : _configHome = configHome ?? _defaultConfigHome(),
      _executable = executable ?? Platform.resolvedExecutable;

  final String _configHome;
  final String _executable;

  static String _defaultConfigHome() =>
      Platform.environment['XDG_CONFIG_HOME'] ??
      p.join(Platform.environment['HOME'] ?? '', '.config');

  String get _entryPath => p.join(_configHome, 'autostart', 'yukari.desktop');

  @override
  bool get supported => true;

  @override
  Future<void> setEnabled(bool enabled) async {
    final entry = File(_entryPath);
    if (!enabled) {
      if (await entry.exists()) await entry.delete();
      return;
    }
    await entry.parent.create(recursive: true);
    await entry.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Yukari\n'
      'Exec="$_executable"\n'
      'Terminal=false\n'
      'X-GNOME-Autostart-enabled=true\n',
    );
  }
}

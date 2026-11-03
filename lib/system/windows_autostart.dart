import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'autostart.dart';

/// Launches Yukari at sign-in through the current user's Run registry key.
final class WindowsAutostart implements Autostart {
  WindowsAutostart({String? executable})
    : _executable = executable ?? Platform.resolvedExecutable;

  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Yukari';

  final String _executable;

  @override
  bool get supported => true;

  @override
  Future<void> setEnabled(bool enabled) async {
    using((arena) {
      final key = arena.pcwstr(_runKey);
      final name = arena.pcwstr(_valueName);
      if (!enabled) {
        RegDeleteKeyValue(HKEY_CURRENT_USER, key, name);
        return;
      }
      final command = '"$_executable"';
      final error = RegSetKeyValue(
        HKEY_CURRENT_USER,
        key,
        name,
        REG_SZ,
        arena.pcwstr(command),
        (command.length + 1) * sizeOf<Uint16>(),
      );
      if (error.isError) throw WindowsException(error.toHRESULT());
    });
  }
}

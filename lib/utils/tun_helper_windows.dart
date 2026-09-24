import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows-specific implementation for checking process elevation.
///
/// Determines if the current process has the administrator privileges
/// required to create TUN devices on Windows.
bool checkWindowsElevation() {
  if (!Platform.isWindows) return false;

  return using((arena) {
    // OpenProcessToken writes the token into a raw pointer slot.
    final tokenSlot = arena<Pointer>();
    final opened = OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, tokenSlot);
    if (!opened.value) return false;

    final token = HANDLE(tokenSlot.value);
    try {
      final elevation = arena<Uint32>();
      final returnLength = arena<Uint32>();

      // TokenElevation fills a TOKEN_ELEVATION struct (a single DWORD).
      final queried = GetTokenInformation(token, TokenElevation, elevation, sizeOf<Uint32>(), returnLength);

      // Non-zero value means elevated
      return queried.value && elevation.value != 0;
    } finally {
      CloseHandle(token);
    }
  });
}

/// Requests elevation by restarting the application with administrator privileges.
///
/// Uses ShellExecuteW with the "runas" verb to trigger UAC prompt.
/// Returns true if the elevation request was initiated successfully.
bool requestWindowsElevation() {
  if (!Platform.isWindows) return false;

  try {
    return using((arena) {
      final result = ShellExecute(
        null,
        arena.pcwstr('runas'),
        arena.pcwstr(Platform.resolvedExecutable),
        null,
        null,
        SW_SHOWNORMAL,
      );

      // ShellExecute returns a value > 32 on success
      return result.address > 32;
    });
  } catch (e) {
    return false;
  }
}

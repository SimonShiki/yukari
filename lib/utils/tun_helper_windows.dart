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

  final processHandle = GetCurrentProcess();
  final tokenHandle = calloc<HANDLE>();

  try {
    // Open the process token
    final result = OpenProcessToken(
      processHandle,
      TOKEN_QUERY,
      tokenHandle,
    );

    if (result != TRUE) {
      return false;
    }

    final token = tokenHandle.value;
    final elevationType = calloc<DWORD>();
    final returnLength = calloc<DWORD>();

    try {
      // Query token elevation information (TokenElevation = 20)
      final queryResult = GetTokenInformation(
        token,
        20, // TokenElevation
        elevationType.cast(),
        sizeOf<DWORD>(),
        returnLength,
      );

      if (queryResult != TRUE) {
        return false;
      }

      // Non-zero value means elevated
      return elevationType.value != 0;
    } finally {
      calloc.free(elevationType);
      calloc.free(returnLength);
      CloseHandle(token);
    }
  } finally {
    calloc.free(tokenHandle);
  }
}

/// Requests elevation by restarting the application with administrator privileges.
///
/// Uses ShellExecuteW with the "runas" verb to trigger UAC prompt.
/// Returns true if the elevation request was initiated successfully.
bool requestWindowsElevation() {
  if (!Platform.isWindows) return false;

  try {
    final executablePath = Platform.resolvedExecutable;
    final lpFile = executablePath.toNativeUtf16();
    final lpVerb = 'runas'.toNativeUtf16();

    try {
      // ShellExecuteW with "runas" triggers UAC elevation
      final result = ShellExecute(
        NULL,
        lpVerb,
        lpFile,
        nullptr,
        nullptr,
        SW_SHOWNORMAL,
      );

      // ShellExecute returns a value > 32 on success
      return result > 32;
    } finally {
      calloc.free(lpFile);
      calloc.free(lpVerb);
    }
  } catch (e) {
    return false;
  }
}

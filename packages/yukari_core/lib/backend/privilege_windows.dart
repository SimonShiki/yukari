import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _seeMaskNoCloseProcess = 0x40;
const _seeMaskNoAsync = 0x100;

/// Whether this process holds administrator privileges, which Windows
/// requires to create TUN devices.
bool isElevated() {
  if (!Platform.isWindows) return false;

  return using((arena) {
    // OpenProcessToken writes the token into a raw pointer slot.
    final tokenSlot = arena<Pointer>();
    final opened = OpenProcessToken(
      GetCurrentProcess(),
      TOKEN_QUERY,
      tokenSlot,
    );
    if (!opened.value) return false;

    final token = HANDLE(tokenSlot.value);
    try {
      final elevation = arena<Uint32>();
      final returnLength = arena<Uint32>();

      // TokenElevation fills a TOKEN_ELEVATION struct (a single DWORD).
      final queried = GetTokenInformation(
        token,
        TokenElevation,
        elevation,
        sizeOf<Uint32>(),
        returnLength,
      );

      // Non-zero value means elevated
      return queried.value && elevation.value != 0;
    } finally {
      CloseHandle(token);
    }
  });
}

/// Restarts the application with administrator privileges via a UAC prompt.
///
/// Returns true if the elevated instance was launched.
bool relaunchElevated() {
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

/// Runs [executable] elevated through a UAC prompt and returns its exit code.
///
/// Waits for the command on another isolate, so the UI stays responsive.
/// Returns [ERROR_CANCELLED] when the user declines the prompt.
Future<int> runElevated(String executable, List<String> arguments) {
  final parameters = arguments.map(quoteArgument).join(' ');
  return Isolate.run(() => _runElevated(executable, parameters));
}

int _runElevated(String executable, String parameters) => using((arena) {
  final info = arena<SHELLEXECUTEINFO>();
  info.ref
    ..cbSize = sizeOf<SHELLEXECUTEINFO>()
    ..fMask = _seeMaskNoCloseProcess | _seeMaskNoAsync
    ..lpVerb = arena.pwstr('runas')
    ..lpFile = arena.pwstr(executable)
    ..lpParameters = arena.pwstr(parameters)
    ..nShow = SW_HIDE;
  final launched = ShellExecuteEx(info);
  if (!launched.value) return launched.error;
  final process = info.ref.hProcess;
  try {
    WaitForSingleObject(process, INFINITE);
    final code = arena<Uint32>();
    return GetExitCodeProcess(process, code).value ? code.value : -1;
  } finally {
    CloseHandle(process);
  }
});

/// Quotes [argument] so CommandLineToArgvW reads it back unchanged.
String quoteArgument(String argument) {
  if (argument.isNotEmpty && !argument.contains(RegExp(r'[\s"]'))) {
    return argument;
  }
  final buffer = StringBuffer('"');
  var backslashes = 0;
  for (final char in argument.split('')) {
    if (char == r'\') {
      backslashes++;
      continue;
    }
    // Backslashes only escape when they precede a quote.
    buffer.write(r'\' * (char == '"' ? backslashes * 2 + 1 : backslashes));
    buffer.write(char);
    backslashes = 0;
  }
  buffer
    ..write(r'\' * (backslashes * 2))
    ..write('"');
  return buffer.toString();
}

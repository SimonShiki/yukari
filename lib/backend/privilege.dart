import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:win32/win32.dart' show ERROR_CANCELLED;

import 'privilege_windows.dart' as windows;

/// Thrown when a command could not run with elevated privileges.
final class ElevationException implements Exception {
  const ElevationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Whether this process can create TUN devices.
///
/// Windows needs an elevated process and Linux needs CAP_NET_ADMIN. Android
/// grants VPN access per network instead, and other platforms are unsupported.
bool canCreateTun() {
  if (Platform.isWindows) return windows.isElevated();
  if (Platform.isLinux) return _hasNetAdminCapability();
  return false;
}

/// Whether this process runs as root or as an elevated administrator.
bool isElevated() =>
    Platform.isWindows ? windows.isElevated() : effectiveUid() == 0;

/// The effective user id of this process on Linux.
int? effectiveUid() => switch (_status('Uid:')) {
  [_, final effective, ...] => int.tryParse(effective),
  _ => null,
};

/// Relaunches the app with administrator privileges, on Windows only.
Future<bool> relaunchElevated() async =>
    Platform.isWindows && windows.relaunchElevated();

/// Runs [executable] with [arguments] as root or administrator.
///
/// Prompts through pkexec on Linux and UAC on Windows unless this process
/// is elevated already. Throws [ElevationException] when the user declines
/// or the command fails.
Future<void> runElevated(String executable, List<String> arguments) async {
  final ProcessResult result;
  if (isElevated()) {
    result = await Process.run(executable, arguments);
  } else if (Platform.isWindows) {
    final code = await windows.runElevated(executable, arguments);
    if (code == 0) return;
    throw ElevationException(
      code == ERROR_CANCELLED
          ? 'Authorization was dismissed'
          : '${p.basename(executable)} failed with code $code',
    );
  } else if (Platform.isLinux) {
    result = await Process.run('pkexec', [executable, ...arguments]);
    // pkexec exits with 126 when dismissed and 127 when not authorized.
    if (result.exitCode case 126 || 127) {
      throw const ElevationException('Authorization was dismissed');
    }
  } else {
    throw const ElevationException('Elevation is unsupported here');
  }
  if (result.exitCode == 0) return;
  final error = '${result.stderr}'.trim();
  throw ElevationException(
    error.isNotEmpty
        ? error
        : '${p.basename(executable)} failed with code ${result.exitCode}',
  );
}

/// Checks if the process has CAP_NET_ADMIN (bit 12) in its effective set.
///
/// /dev/net/tun is usually world-writable, but creating the interface
/// (TUNSETIFF) still requires CAP_NET_ADMIN, failing with EPERM otherwise.
/// Root has all capabilities, so this covers both root and setcap'd binaries.
bool _hasNetAdminCapability() {
  final caps = switch (_status('CapEff:')) {
    [final value, ...] => BigInt.tryParse(value, radix: 16),
    _ => null,
  };
  return caps != null && (caps >> 12) & BigInt.one == BigInt.one;
}

/// The fields of the [key] line in /proc/self/status, or null if unreadable.
List<String>? _status(String key) {
  try {
    final line = File('/proc/self/status')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith(key));
    return line.substring(key.length).trim().split(RegExp(r'\s+'));
  } catch (_) {
    return null;
  }
}

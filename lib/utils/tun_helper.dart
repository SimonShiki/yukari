import 'dart:io';

// Conditional import: use Windows implementation only on Windows
import 'tun_helper_io.dart' if (dart.library.io) 'tun_helper_windows.dart';
import 'vpn_service_android.dart' if (dart.library.html) 'vpn_service_stub.dart';

/// Checks if the current process can create TUN devices.
///
/// Returns `true` if:
/// - On Android: Always true (VPN permission is checked at runtime)
/// - On Windows: Process is running with administrator privileges (elevated)
/// - On Unix/Linux/macOS: Can access /dev/net/tun with read/write permissions
///
/// Returns `false` otherwise or if the check cannot be performed.
bool canCreateTun() {
  if (Platform.isAndroid) {
    // On Android, VPN permission is checked at runtime
    return true;
  } else if (Platform.isWindows) {
    return checkWindowsElevation();
  } else if (Platform.isLinux || Platform.isMacOS) {
    return _canAccessTunDevice();
  }
  return false;
}

/// Requests elevation/permission to gain access for creating TUN devices.
///
/// On Android: Requests VPN permission via system dialog.
/// On Windows: Restarts the application with administrator privileges via UAC.
/// On Linux: Restarts the application with pkexec (Polkit GUI authentication).
/// On macOS: Returns false (manual elevation required).
///
/// Returns `true` if the elevation/permission request was initiated successfully.
/// Note: On desktop platforms, if successful, a new elevated instance is launched.
/// The caller should handle application exit if needed.
Future<bool> requestTunPermission() async {
  if (Platform.isAndroid) {
    return await AndroidVpnService.requestVpnPermission();
  } else if (Platform.isWindows) {
    return requestWindowsElevation();
  } else if (Platform.isLinux) {
    return _requestLinuxElevation();
  }
  // On macOS, elevation typically requires manual restart with sudo
  return false;
}

/// Requests elevation on Linux using pkexec (Polkit).
///
/// This launches a new instance of the application with elevated privileges
/// via pkexec, which shows a GUI authentication dialog to the user.
bool _requestLinuxElevation() {
  try {
    // Get the executable path
    final executablePath = Platform.resolvedExecutable;

    // Get current command-line arguments to pass to the elevated instance
    final args = Platform.executableArguments;

    // Launch elevated instance using pkexec
    // pkexec will show a GUI authentication dialog
    Process.start('pkexec', [executablePath, ...args], mode: ProcessStartMode.detached);

    return true;
  } catch (e) {
    // pkexec not available or failed to start
    return false;
  }
}

/// Checks if /dev/net/tun exists and is accessible (read/write) on Unix-like systems.
///
/// This directly tests what the TUN device creation requires at the kernel level:
/// the ability to open /dev/net/tun with O_RDWR. This works for:
/// - Root users (UID 0)
/// - Non-root users with CAP_NET_ADMIN capability and file access
/// - Non-root users when /dev/net/tun has permissive permissions
bool _canAccessTunDevice() {
  try {
    // Check if /dev/net/tun exists
    final file = File('/dev/net/tun');
    if (!file.existsSync()) {
      return false;
    }

    // Test actual read/write access using shell test command
    // This matches what rust-tun does: open(/dev/net/tun, O_RDWR)
    final result = Process.runSync('test', ['-r', '/dev/net/tun', '-a', '-w', '/dev/net/tun']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

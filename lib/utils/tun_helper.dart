import 'dart:io';

// Conditional import: use Windows implementation only on Windows
import 'tun_helper_io.dart' if (dart.library.io) 'tun_helper_windows.dart';
import 'vpn_service_android.dart' if (dart.library.html) 'vpn_service_stub.dart';

/// Checks if the current process can create TUN devices.
///
/// Returns `true` if:
/// - On Android: Always true (VPN permission is checked at runtime)
/// - On Windows: Process is running with administrator privileges (elevated)
/// - On Linux: Process has CAP_NET_ADMIN in its effective capability set
///
/// Returns `false` otherwise or if the check cannot be performed.
bool canCreateTun() {
  if (Platform.isAndroid) {
    // On Android, VPN permission is checked at runtime
    return true;
  } else if (Platform.isWindows) {
    return checkWindowsElevation();
  } else if (Platform.isLinux) {
    return _hasNetAdminCapability();
  }
  return false;
}

/// Requests elevation/permission to gain access for creating TUN devices.
///
/// On Android: Requests VPN permission via system dialog.
/// On Windows: Restarts the application with administrator privileges via UAC.
/// On Linux/macOS: Returns false (manual elevation required).
///
/// Returns `true` if the elevation/permission request was initiated successfully.
/// Note: On desktop platforms, if successful, a new elevated instance is launched.
/// The caller should handle application exit if needed.
Future<bool> requestTunPermission() async {
  if (Platform.isAndroid) {
    return await AndroidVpnService.requestVpnPermission();
  } else if (Platform.isWindows) {
    return requestWindowsElevation();
  }
  return false;
}

/// Checks if the process has CAP_NET_ADMIN (bit 12) in its effective set.
///
/// /dev/net/tun is usually world-writable, but creating the interface
/// (TUNSETIFF) still requires CAP_NET_ADMIN, failing with EPERM otherwise.
/// Root has all capabilities, so this covers both root and setcap'd binaries.
bool _hasNetAdminCapability() {
  try {
    final line = File('/proc/self/status')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('CapEff:'));
    final caps = BigInt.parse(line.substring(7).trim(), radix: 16);
    return (caps >> 12) & BigInt.one == BigInt.one;
  } catch (e) {
    return false;
  }
}

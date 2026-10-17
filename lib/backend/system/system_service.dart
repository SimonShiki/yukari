import 'dart:io';

import '../../models/backend.dart';
import 'systemd_service.dart';
import 'windows_service.dart';

/// The background service as registered with the OS service manager, which
/// starts it on boot with full privileges.
///
/// [install], [uninstall], [start] and [stop] need root or administrator;
/// the service executable runs them for the app through `ServiceControl`.
abstract class SystemService {
  static const name = 'yukari';

  /// The service manager of this platform, or null when unsupported.
  static SystemService? get current {
    if (Platform.isWindows) return WindowsService();
    if (Platform.isLinux && Directory('/run/systemd/system').existsSync()) {
      return SystemdService();
    }
    return null;
  }

  Future<ServiceState> state();

  /// Prepares the app's bundled [executable] for registration and returns the
  /// path to register.
  ///
  /// A service manager that runs the file where it lies registers [executable]
  /// itself. Windows registers a privileged copy instead, so that a running
  /// service does not hold the app's own file open.
  Future<String> prepare(String executable) async => executable;

  /// Registers [executable] with [arguments] to start on boot, and starts it.
  /// Reinstalling replaces the registration and restarts the service.
  Future<void> install(String executable, List<String> arguments);

  /// Stops the service and removes its registration.
  Future<void> uninstall();

  Future<void> start();

  Future<void> stop();
}

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/backend.dart';
import '../privilege.dart';
import 'system_service.dart';

/// Installs and controls the background service from the unprivileged app.
abstract interface class ServiceControl {
  /// The app's data directory, whose networks the service runs.
  String get dataDir;

  /// Whether this platform and build can run the service.
  bool get supported;

  Future<ServiceState> state();

  /// Installs the service for this user's networks, or reinstalls it, such
  /// as after an update moved the executable or changed the service.
  ///
  /// Reports how much of a download is done, from 0 to 1, to [onProgress],
  /// and null while that is unknown.
  Future<void> install({void Function(double? progress)? onProgress});

  Future<void> uninstall();

  Future<void> start();

  Future<void> stop();
}

/// Controls the service registered with the desktop OS service manager.
///
/// Changes run the bundled service executable elevated, which registers
/// itself with the OS; see `bin/yukari_service.dart`.
final class SystemServiceControl implements ServiceControl {
  SystemServiceControl({
    required this.dataDir,
    SystemService? system,
    String? executable,
  }) : system = system ?? SystemService.current,
       executable = executable ?? bundledExecutable;

  @override
  final String dataDir;
  final SystemService? system;
  final String executable;

  /// The service executable bundled in `bin/` beside the app.
  static String get bundledExecutable => p.join(
    p.dirname(Platform.resolvedExecutable),
    'bin',
    Platform.isWindows ? 'yukari-service.exe' : 'yukari-service',
  );

  @override
  bool get supported => system != null && File(executable).existsSync();

  @override
  Future<ServiceState> state() async =>
      supported ? await system!.state() : ServiceState.unsupported;

  /// Registers the bundled executable, so there is nothing to download.
  @override
  Future<void> install({void Function(double? progress)? onProgress}) =>
      runElevated(executable, [
        'install',
        '--data-dir',
        dataDir,
        if (effectiveUid() case final uid?) ...['--owner-uid', '$uid'],
      ]);

  @override
  Future<void> uninstall() => runElevated(executable, ['uninstall']);

  @override
  Future<void> start() => runElevated(executable, ['start']);

  @override
  Future<void> stop() => runElevated(executable, ['stop']);
}

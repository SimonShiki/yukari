import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/backend.dart';
import '../privilege.dart';
import 'system_service.dart';

/// Installs and controls the background service from the unprivileged app.
///
/// Changes run the bundled service executable elevated, which registers
/// itself with the OS; see `bin/yukari_service.dart`.
final class ServiceControl {
  ServiceControl({
    required this.dataDir,
    SystemService? system,
    String? executable,
  }) : system = system ?? SystemService.current,
       executable = executable ?? bundledExecutable;

  /// The app's data directory, whose networks the service runs.
  final String dataDir;
  final SystemService? system;
  final String executable;

  /// The service executable bundled in `bin/` beside the app.
  static String get bundledExecutable => p.join(
    p.dirname(Platform.resolvedExecutable),
    'bin',
    Platform.isWindows ? 'yukari-service.exe' : 'yukari-service',
  );

  /// Whether this platform and build can run the service.
  bool get supported => system != null && File(executable).existsSync();

  Future<ServiceState> state() async =>
      supported ? await system!.state() : ServiceState.unsupported;

  /// Installs the service for this user's networks, or reinstalls it, such
  /// as after an update moved the executable.
  Future<void> install() => runElevated(executable, [
    'install',
    '--data-dir',
    dataDir,
    if (effectiveUid() case final uid?) ...['--owner-uid', '$uid'],
  ]);

  Future<void> uninstall() => runElevated(executable, ['uninstall']);

  Future<void> start() => runElevated(executable, ['start']);

  Future<void> stop() => runElevated(executable, ['stop']);
}

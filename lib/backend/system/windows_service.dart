import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import '../../models/backend.dart';
import '../privilege_windows.dart';
import 'system_service.dart';

/// The service as registered with the Windows service control manager.
///
/// Changes go through sc.exe, which exits with the Win32 error code.
///
/// The service runs from a copy of the app's own files, in
/// `%ProgramFiles%\Yukari\service`, rather than from the app's directory. A
/// running service holds its own executable open, so a service registered in the
/// app's directory keeps every later build from replacing it. The copy also has
/// to be somewhere the people using the app cannot write: the service runs as
/// LocalSystem, and in a development build the app's directory is the user's own
/// build output. `%ProgramFiles%` grants users read and execute alone, and the
/// app's files stay free to replace.
final class WindowsService extends SystemService {
  WindowsService({String? root}) : root = root ?? defaultRoot;

  static const _name = SystemService.name;

  /// Where the copy the service runs from lives.
  final String root;

  static String get defaultRoot => p.join(
    Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
    'Yukari',
    'service',
  );

  @override
  Future<String> prepare(String executable) async {
    // The copy being replaced is the file the service runs from.
    await stop();
    return stage(executable);
  }

  /// Replaces the copy with the bundle around [executable] and returns the copy
  /// to register.
  ///
  /// [executable] is the app's `bin/yukari-service.exe`; the service finds its
  /// native libraries in the `lib` directory beside that `bin`, so the copy
  /// keeps the same layout. [prepare] stops the service first, because the copy
  /// being replaced is the file it runs from.
  Future<String> stage(String executable) async {
    final bin = File(executable).parent;
    final lib = Directory(p.join(bin.parent.path, 'lib'));
    final directory = Directory(root);
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    await _copyInto(bin, Directory(p.join(root, 'bin')));
    if (await lib.exists()) {
      await _copyInto(lib, Directory(p.join(root, 'lib')));
    }
    return p.join(root, 'bin', p.basename(executable));
  }

  /// Removes the copy, if there is one.
  Future<void> removeBundle() async {
    final directory = Directory(root);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<ServiceState> state() async => switch (_query()) {
    null => ServiceState.notInstalled,
    SERVICE_RUNNING => ServiceState.running,
    _ => ServiceState.stopped,
  };

  /// The raw state of the service, or null when it is not installed.
  static int? _query() => using((arena) {
    final manager = OpenSCManager(null, null, SC_MANAGER_CONNECT);
    if (!manager.value.isValid) {
      throw WindowsException(HRESULT_FROM_WIN32(manager.error));
    }
    try {
      final service = OpenService(
        manager.value,
        arena.pcwstr(_name),
        SERVICE_QUERY_STATUS,
      );
      if (!service.value.isValid) {
        if (service.error == ERROR_SERVICE_DOES_NOT_EXIST) return null;
        throw WindowsException(HRESULT_FROM_WIN32(service.error));
      }
      try {
        final status = arena<SERVICE_STATUS>();
        final queried = QueryServiceStatus(service.value, status);
        if (!queried.value) {
          throw WindowsException(HRESULT_FROM_WIN32(queried.error));
        }
        return status.ref.dwCurrentState;
      } finally {
        CloseServiceHandle(service.value);
      }
    } finally {
      CloseServiceHandle(manager.value);
    }
  });

  @override
  Future<void> install(String executable, List<String> arguments) async {
    final command = [executable, ...arguments].map(quoteArgument).join(' ');
    final options = ['binPath=', command, 'start=', 'auto'];
    if (await state() == ServiceState.notInstalled) {
      await _sc(['create', _name, ...options, 'DisplayName=', 'Yukari']);
    } else {
      await _sc(['config', _name, ...options]);
      await stop();
    }
    await _sc([
      'description',
      _name,
      'Runs Yukari networks in the background.',
    ]);
    // Restart after crashes and after failures the service reports itself.
    await _sc([
      'failure',
      _name,
      'reset=',
      '86400',
      'actions=',
      'restart/1000/restart/5000/restart/10000',
    ]);
    await _sc(['failureflag', _name, '1']);
    await start();
  }

  @override
  Future<void> uninstall() async {
    await stop();
    await _sc(['delete', _name], ignore: [ERROR_SERVICE_DOES_NOT_EXIST]);
    await removeBundle();
  }

  @override
  Future<void> start() =>
      _sc(['start', _name], ignore: [ERROR_SERVICE_ALREADY_RUNNING]);

  /// Stops the service and waits until it has stopped.
  @override
  Future<void> stop() async {
    await _sc(
      ['stop', _name],
      ignore: [ERROR_SERVICE_NOT_ACTIVE, ERROR_SERVICE_DOES_NOT_EXIST],
    );
    for (
      var i = 0;
      i < 60 && (_query() ?? SERVICE_STOPPED) != SERVICE_STOPPED;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<void> _sc(
    List<String> arguments, {
    List<int> ignore = const [],
  }) async {
    final result = await Process.run('sc.exe', arguments);
    if (result.exitCode == 0 || ignore.contains(result.exitCode)) return;
    throw ProcessException(
      'sc.exe',
      arguments,
      '${result.stdout}'.trim(),
      result.exitCode,
    );
  }
}

/// Copies every file of [source] into [target], keeping the layout.
Future<void> _copyInto(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entry in source.list(recursive: true)) {
    final destination = p.join(
      target.path,
      p.relative(entry.path, from: source.path),
    );
    if (entry is Directory) {
      await Directory(destination).create(recursive: true);
    } else if (entry is File) {
      await entry.copy(destination);
    }
  }
}

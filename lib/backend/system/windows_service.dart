import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/backend.dart';
import '../privilege_windows.dart';
import 'system_service.dart';

/// The service as registered with the Windows service control manager.
///
/// Changes go through sc.exe, which exits with the Win32 error code.
final class WindowsService extends SystemService {
  static const _name = SystemService.name;

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

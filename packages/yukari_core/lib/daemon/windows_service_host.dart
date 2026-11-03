import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _acceptStop = 0x1;
const _acceptShutdown = 0x4;
const _controlStop = 0x1;
const _controlInterrogate = 0x4;
const _controlShutdown = 0x5;
const _serviceSpecificError = 1066;
const int _notImplemented = ERROR_CALL_NOT_IMPLEMENTED;

/// Runs [body] as the Windows service [name] and returns true, or returns
/// false right away when the service control manager did not start this
/// process, so the caller can run in the console instead.
///
/// [body] receives a future that completes when Windows asks the service to
/// stop, and must complete once it has stopped.
///
/// The control dispatcher blocks its thread, so it runs on a helper
/// isolate; its control handler, called back on that same thread, forwards
/// requests here. ServiceMain arrives on a thread of its own and may return
/// at once: the service lives until it reports that it stopped.
Future<bool> runWindowsService(
  String name,
  Future<void> Function(Future<void> stopping) body,
) async {
  final inbox = ReceivePort();
  final handler = Completer<int>();
  final ended = Completer<int>();
  final started = Completer<void>();
  final stopping = Completer<void>();
  SERVICE_STATUS_HANDLE? status;

  final serviceMain = NativeCallable<LPSERVICE_MAIN_FUNCTION>.listener((
    int argc,
    Pointer<Pointer<Utf16>> argv,
  ) {
    if (!started.isCompleted) started.complete();
  });
  inbox.listen((message) {
    switch (message) {
      case int address:
        handler.complete(address);
      case ('ended', int error):
        ended.complete(error);
      case ('control', _controlStop || _controlShutdown)
          when !stopping.isCompleted:
        if (status case final status?) {
          _report(status, SERVICE_STOP_PENDING, waitHint: 30000);
        }
        stopping.complete();
    }
  });
  try {
    await Isolate.spawn(_dispatch, (
      name,
      serviceMain.nativeFunction.address,
      inbox.sendPort,
    ));
    final handlerAddress = await handler.future;
    final error = await Future.any([
      started.future.then((_) => null),
      ended.future,
    ]);
    if (error == ERROR_FAILED_SERVICE_CONTROLLER_CONNECT) return false;
    if (error != null) {
      throw WindowsException(HRESULT_FROM_WIN32(WIN32_ERROR(error)));
    }

    final registered = using(
      (arena) => RegisterServiceCtrlHandlerEx(
        arena.pcwstr(name),
        Pointer.fromAddress(handlerAddress),
        null,
      ),
    );
    if (!registered.value.isValid) {
      throw WindowsException(HRESULT_FROM_WIN32(registered.error));
    }
    status = registered.value;
    _report(status, SERVICE_RUNNING);
    try {
      await body(stopping.future);
      _report(status, SERVICE_STOPPED);
    } catch (_) {
      // A service-specific error makes Windows apply the restart actions.
      _report(status, SERVICE_STOPPED, exitCode: _serviceSpecificError);
      rethrow;
    } finally {
      await ended.future;
    }
    return true;
  } finally {
    inbox.close();
    serviceMain.close();
  }
}

void _report(
  SERVICE_STATUS_HANDLE handle,
  SERVICE_STATUS_CURRENT_STATE state, {
  int exitCode = 0,
  int waitHint = 0,
}) => using((arena) {
  final status = arena<SERVICE_STATUS>();
  status.ref
    ..dwServiceType = SERVICE_WIN32_OWN_PROCESS
    ..dwCurrentState = state
    ..dwControlsAccepted = state == SERVICE_RUNNING
        ? _acceptStop | _acceptShutdown
        : 0
    ..dwWin32ExitCode = exitCode
    ..dwServiceSpecificExitCode = exitCode == 0 ? 0 : 1
    ..dwCheckPoint = waitHint == 0 ? 0 : 1
    ..dwWaitHint = waitHint;
  SetServiceStatus(handle, status);
});

/// Where the control handler forwards requests; set in [_dispatch].
late SendPort _controls;

int _handleControl(int control, int eventType, Pointer data, Pointer context) {
  _controls.send(('control', control));
  return switch (control) {
    _controlStop || _controlShutdown || _controlInterrogate => NO_ERROR,
    _ => _notImplemented,
  };
}

/// Runs the control dispatcher until the service stops.
void _dispatch((String, int, SendPort) arguments) {
  final (name, serviceMain, inbox) = arguments;
  _controls = inbox;
  final handler = NativeCallable<LPHANDLER_FUNCTION_EX>.isolateLocal(
    _handleControl,
    exceptionalReturn: _notImplemented,
  );
  inbox.send(handler.nativeFunction.address);
  final error = using((arena) {
    // The table ends with an all-zero entry; the arena zeroes memory.
    final table = arena<SERVICE_TABLE_ENTRY>(2);
    table[0]
      ..lpServiceName = arena.pwstr(name)
      ..lpServiceProc = Pointer.fromAddress(serviceMain);
    final result = StartServiceCtrlDispatcher(table);
    return result.value ? 0 : result.error;
  });
  handler.close();
  inbox.send(('ended', error));
}

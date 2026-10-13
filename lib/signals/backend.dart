import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../backend/android_backend.dart';
import '../backend/backend.dart';
import '../backend/ffi_backend.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../backend/service_backend.dart';
import '../backend/system/service_control.dart';
import '../models/models.dart';

/// Private backing signal for the active backend.
/// Use [backend] for readonly access and [switchBackend] for changes.
final Signal<NetworkBackend> _backend = signal(FfiBackend());

/// The backend that runs network instances: in process, or in the service.
///
/// **Initialization**: Call [initBackend] once at app startup.
///
/// **Mutation**: Use [switchBackend]; the choice persists across launches.
///
/// **Read**: Read `backend.value` when acting rather than holding on to it,
/// as it changes when the user switches.
ReadonlySignal<NetworkBackend> get backend => _backend;

/// Controls the background service, which [BackendKind.service] talks to.
late final ServiceControl serviceControl;

const _kindKey = 'backend';

/// Restores the backend the user chose, for the app data directory [dataDir].
Future<void> initBackend(String dataDir) async {
  serviceControl = ServiceControl(dataDir: dataDir);
  final saved = (await SharedPreferences.getInstance()).getString(_kindKey);
  final kind = BackendKind.values.asNameMap()[saved] ?? BackendKind.ffi;
  _backend.value = _create(
    kind == BackendKind.service && serviceControl.supported
        ? kind
        : BackendKind.ffi,
  );
}

/// Switches to the [kind] backend. Instances of an in-process backend stop.
Future<void> switchBackend(BackendKind kind) async {
  if (_backend.peek().kind == kind) return;
  final previous = _backend.peek();
  _backend.value = _create(kind);
  await (await SharedPreferences.getInstance()).setString(_kindKey, kind.name);
  await previous.dispose();
}

NetworkBackend _create(BackendKind kind) => switch (kind) {
  BackendKind.service => ServiceBackend(
    () => IpcEndpoint.locate(serviceControl.dataDir),
  ),
  BackendKind.ffi => Platform.isAndroid ? AndroidBackend() : FfiBackend(),
};

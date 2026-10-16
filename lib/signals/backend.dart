import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../backend/android_backend.dart';
import '../backend/backend.dart';
import '../backend/ffi_backend.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../backend/service_backend.dart';
import '../backend/system/module_service_control.dart';
import '../backend/system/service_control.dart';
import '../models/models.dart';

final _backendKind = signal<BackendKind>(BackendKind.ffi);

/// Private backing signal for the active backend.
/// Use [backend] for readonly access and [switchBackend] for changes.
late final Signal<NetworkBackend> _backend;

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

/// Restores the backend the user chose, for the app data directory [dataDir].
Future<void> initBackend(String dataDir) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('backend');
  BackendKind chosen = BackendKind.values.asNameMap()[saved] ?? BackendKind.ffi;

  serviceControl = Platform.isAndroid
      ? ModuleServiceControl(dataDir: dataDir)
      : SystemServiceControl(dataDir: dataDir);
  if (chosen == BackendKind.service && !serviceControl.supported) {
    chosen = BackendKind.ffi;
  }

  _backendKind.set(chosen);
  _backend.value = _create(chosen);
}

/// Switches to the [kind] backend. Instances of an in-process backend stop.
Future<void> switchBackend(BackendKind kind) async {
  if (_backend.peek().kind == kind) return;
  final previous = _backend.peek();
  _backend.value = _create(kind);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('backend', kind.name);
  await previous.dispose();
}

NetworkBackend _create(BackendKind kind) => switch (kind) {
  BackendKind.service => ServiceBackend(
    () => IpcEndpoint.locate(serviceControl.dataDir),
  ),
  BackendKind.ffi => Platform.isAndroid ? AndroidBackend() : FfiBackend(),
};

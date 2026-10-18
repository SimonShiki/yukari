import 'dart:io';

import 'package:signals/signals.dart';

import '../backend/android_backend.dart';
import '../backend/backend.dart';
import '../backend/ffi_backend.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../backend/service_backend.dart';
import '../backend/system/module_service_control.dart';
import '../backend/system/service_control.dart';
import '../models/models.dart';
import '../system/android_system_ui.dart';
import 'settings.dart';

/// Private backing signal for the active backend.
/// Use [backend] for readonly access and [switchBackend] for changes.
final Signal<NetworkBackend> _backend = signal(FfiBackend());

/// The backend that runs network instances: in process, or in the service.
///
/// **Initialization**: Call [initBackend] once at app startup, after
/// [initSettings].
///
/// **Mutation**: Use [switchBackend]; the choice persists across launches.
///
/// **Read**: Read `backend.value` when acting rather than holding on to it,
/// as it changes when the user switches.
ReadonlySignal<NetworkBackend> get backend => _backend;

/// The active backend's kind, for every page that reads it.
final Computed<BackendKind> backendKind = computed(() => _backend.value.kind);

/// The active backend's connection status, for every page that reads it.
final Computed<BackendStatus> backendStatus = computed(
  () => _backend.value.status.value,
);

/// Controls the background service, which [BackendKind.service] talks to.
late final ServiceControl serviceControl;

/// Restores the backend the user chose, for the app data directory [dataDir].
Future<void> initBackend(String dataDir) async {
  serviceControl = Platform.isAndroid
      ? ModuleServiceControl(dataDir: dataDir)
      : SystemServiceControl(dataDir: dataDir);
  final preferred = settings.workingMode.backend.value;
  _backend.value = _create(_available(preferred));
  if (Platform.isAndroid) {
    await AndroidSystemUi(
      backend: backend,
      backendKind: backendKind,
      backendStatus: backendStatus,
      serviceControl: serviceControl,
    ).start();
  }
}

/// Switches to the [kind] backend. Instances of an in-process backend stop.
Future<void> switchBackend(BackendKind kind) async {
  if (_backend.peek().kind == kind) return;
  final previous = _backend.peek();
  _backend.value = _create(kind);
  settings.workingMode.setBackend(kind);
  await previous.dispose();
}

/// [kind], or the in-process backend when the service cannot run here.
BackendKind _available(BackendKind kind) =>
    kind == BackendKind.service && serviceControl.supported
    ? kind
    : BackendKind.ffi;

NetworkBackend _create(BackendKind kind) => switch (kind) {
  BackendKind.service => ServiceBackend(
    () => IpcEndpoint.locate(serviceControl.dataDir),
  ),
  BackendKind.ffi => Platform.isAndroid ? AndroidBackend() : FfiBackend(),
};

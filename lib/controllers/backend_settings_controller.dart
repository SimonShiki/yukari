import 'package:signals/signals.dart';

import '../backend/ipc/ipc_client.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../backend/service_version.dart';
import '../backend/system/service_control.dart';
import '../models/backend.dart';
import '../signals/backend.dart';
import '../signals/locale.dart';

/// Chooses where networks run and manages the background service.
class BackendSettingsController {
  BackendSettingsController({
    required this.showMessage,
    required this.confirmStopNetworks,
    ServiceControl? control,
    Future<int?> Function()? probeVersion,
  }) : control = control ?? serviceControl {
    _probeVersion = probeVersion ?? _probeRunningVersion;
  }

  final void Function(String message) showMessage;

  /// Asks whether the [running] networks may stop for the switch to
  /// [target].
  final Future<bool> Function(BackendKind target, int running)
  confirmStopNetworks;
  final ServiceControl control;

  /// Asks the running service its version; null when it cannot be reached.
  late final Future<int?> Function() _probeVersion;

  final serviceState = signal(ServiceState.unsupported);
  final busy = signal(false);

  /// The version the running service reports, or null when unknown.
  final runningVersion = signal<int?>(null);

  /// Whether an install is underway, and how much of its download is done,
  /// from 0 to 1; null while that is unknown or the download is over.
  final installing = signal(false);
  final installProgress = signal<double?>(null);

  late final kind = computed(() => backend.value.kind);
  late final status = computed(() => backend.value.status.value);

  /// Whether the running service is older than this app.
  late final outdated = computed(
    () => (runningVersion.value ?? serviceVersion) < serviceVersion,
  );

  Future<void> refresh() async {
    try {
      final state = await control.state();
      serviceState.value = state;
      runningVersion.value = state == ServiceState.running
          ? await _probeVersion()
          : null;
    } catch (e) {
      showMessage(l10n.value.controllerCheckService(e.toString()));
    }
  }

  Future<void> select(BackendKind kind) async {
    if (busy.value || kind == this.kind.value) return;
    if (kind == BackendKind.service) {
      switch (serviceState.value) {
        case ServiceState.running || ServiceState.stopped:
          break;
        case ServiceState.rootRequired:
          showMessage(l10n.value.controllerRootRequired);
          return;
        case ServiceState.unsupported || ServiceState.notInstalled:
          showMessage(l10n.value.controllerInstallRequired);
          return;
      }
    }
    final active = backend.value;
    // Stop what runs where networks ran so far, so that none keeps running
    // unseen; an unreachable service has nothing to stop.
    final running = await active.collectInfos().catchError(
      (Object _) => <String, String>{},
    );
    if (running.isNotEmpty) {
      if (!await confirmStopNetworks(kind, running.length)) return;
      try {
        await active.stop(running.keys.toList());
      } catch (e) {
        showMessage(l10n.value.controllerStopNetworks(e.toString()));
        return;
      }
    }
    await switchBackend(kind);
  }

  /// Installs the service, or updates it to this app's version.
  Future<void> install() => _change(() async {
    installing.value = true;
    installProgress.value = null;
    try {
      await control.install(
        onProgress: (progress) => installProgress.value = progress,
      );
    } finally {
      installing.value = false;
    }
  }, 'install');

  Future<void> start() => _change(control.start, 'start');

  Future<void> stop() => _change(control.stop, 'stop');

  Future<void> uninstall() async {
    await _change(control.uninstall, 'uninstall');
    if (serviceState.value == ServiceState.notInstalled &&
        kind.value == BackendKind.service) {
      await switchBackend(BackendKind.ffi);
    }
  }

  Future<void> _change(Future<void> Function() action, String verb) async {
    if (busy.value) return;
    busy.value = true;
    try {
      await action();
    } catch (e) {
      showMessage(switch (verb) {
        'install' => l10n.value.controllerServiceInstall(e.toString()),
        'start' => l10n.value.controllerServiceStart(e.toString()),
        'stop' => l10n.value.controllerServiceStop(e.toString()),
        _ => l10n.value.controllerServiceUninstall(e.toString()),
      });
    } finally {
      await refresh();
      busy.value = false;
    }
  }

  /// Tries for a few seconds, as a service just (re)started takes a moment
  /// to listen.
  Future<int?> _probeRunningVersion() async {
    for (var attempt = 1; ; attempt++) {
      try {
        final version = await runningServiceVersion(
          await IpcEndpoint.locate(control.dataDir),
        );
        if (version != null || attempt == 6) return version;
      } catch (_) {
        if (attempt == 6) return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  void dispose() {
    kind.dispose();
    status.dispose();
    outdated.dispose();
  }
}

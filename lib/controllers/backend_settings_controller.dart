import 'package:signals/signals.dart';

import '../backend/system/service_control.dart';
import '../models/backend.dart';
import '../signals/backend.dart';

/// Chooses where networks run and manages the background service.
class BackendSettingsController {
  BackendSettingsController({
    required this.showMessage,
    required this.confirmStopNetworks,
    ServiceControl? control,
  }) : control = control ?? serviceControl;

  final void Function(String message) showMessage;

  /// Asks whether networks running in the app may stop.
  final Future<bool> Function() confirmStopNetworks;
  final ServiceControl control;

  final serviceState = signal(ServiceState.unsupported);
  final busy = signal(false);
  late final kind = computed(() => backend.value.kind);
  late final status = computed(() => backend.value.status.value);

  Future<void> refresh() async {
    try {
      serviceState.value = await control.state();
    } catch (e) {
      showMessage('Could not check the service: $e');
    }
  }

  Future<void> select(BackendKind kind) async {
    if (busy.value || kind == this.kind.value) return;
    final installed = switch (serviceState.value) {
      ServiceState.running || ServiceState.stopped => true,
      ServiceState.unsupported || ServiceState.notInstalled => false,
    };
    if (kind == BackendKind.service && !installed) {
      showMessage('Install the background service first.');
      return;
    }
    final active = backend.value;
    // Networks running in the app stop with it; the service's keep running.
    if (active.kind == BackendKind.ffi) {
      final running = await active.collectInfos().catchError(
        (Object _) => <String, String>{},
      );
      if (running.isNotEmpty && !await confirmStopNetworks()) return;
    }
    await switchBackend(kind);
  }

  Future<void> install() => _change(control.install, 'install');

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
      showMessage('Could not $verb the service: $e');
    } finally {
      await refresh();
      busy.value = false;
    }
  }

  void dispose() {
    kind.dispose();
    status.dispose();
  }
}

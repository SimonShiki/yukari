import 'package:flutter/widgets.dart';
import 'package:signals/signals.dart';

import '../backend/backend.dart';
import '../backend/ipc/ipc_client.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../backend/service_backend.dart';
import '../backend/service_version.dart';
import '../backend/system/service_control.dart';
import '../models/models.dart';
import '../signals/backend.dart' as backend_signals;
import '../signals/locale.dart';
import '../signals/networks.dart';

/// How often the version probe retries while a just-restarted service is
/// briefly unreachable, and how long it waits in between.
const _probeAttempts = 6;
const _probeInterval = Duration(milliseconds: 500);

/// The settings page's signals and actions: where the networks run, the state
/// of the background service, and the interface language.
class BackendSettingsController {
  BackendSettingsController({
    required this.showMessage,
    required this.confirmStopNetworks,
    ServiceControl? control,
    Future<int?> Function()? probeVersion,
    ReadonlySignal<NetworkBackend>? backend,
  }) : control = control ?? backend_signals.serviceControl,
       _probe = probeVersion,
       _backend = backend ?? backend_signals.backend,
       _injected = backend != null;

  /// Reports a user-visible outcome.
  final void Function(String message) showMessage;

  /// Asks whether to stop [count] running networks before switching to [kind];
  /// false keeps them running and cancels the switch.
  final Future<bool> Function(BackendKind kind, int count) confirmStopNetworks;

  /// The service this page installs and controls.
  final ServiceControl control;
  final Future<int?> Function()? _probe;

  /// The active backend; injectable so tests can drive its kind and status.
  final ReadonlySignal<NetworkBackend> _backend;

  /// Whether [_backend] was injected. An injected backend is not owned here:
  /// only the [kind] and [status] derivations over it are disposed with this
  /// controller.
  final bool _injected;
  final List<void Function()> _disposers = [];
  bool _disposed = false;

  /// The service's installation and run state, as last refreshed.
  final Signal<ServiceState> serviceState = signal(ServiceState.unsupported);

  /// Whether [refresh] has answered yet, success or failure.
  ///
  /// [serviceState] starts at [ServiceState.unsupported], which is a wrong
  /// answer rather than an unknown one: the page shows a neutral loading form
  /// until this is true, so the real state replaces nothing the user is
  /// already reading.
  final Signal<bool> stateKnown = signal(false);

  /// Whether an action is in flight; gates every mutation.
  final Signal<bool> busy = signal(false);

  /// The version the running service reported, or null while unknown.
  final Signal<int?> runningVersion = signal(null);

  /// Whether an install is in flight, and how far its download is.
  final Signal<bool> installing = signal(false);
  final Signal<double?> installProgress = signal(null);

  /// The active backend's kind and connection status: the app-wide signals,
  /// or the injected backend's, which this controller owns.
  late final ReadonlySignal<BackendKind> kind = _injected
      ? _derived(() => _backend.value.kind)
      : backend_signals.backendKind;
  late final ReadonlySignal<BackendStatus> status = _injected
      ? _derived(() => _backend.value.status.value)
      : backend_signals.backendStatus;

  /// A signal this controller created, and so disposes with it.
  ReadonlySignal<T> _derived<T>(T Function() compute) {
    final created = computed<T>(compute);
    _disposers.add(created.dispose);
    return created;
  }

  /// Whether the running service is older than the one this app ships.
  late final Computed<bool> outdated = computed(
    () => (runningVersion.value ?? serviceVersion) < serviceVersion,
  );

  /// The language the user picked, or null to follow the system.
  ReadonlySignal<Locale?> get language => preferredLocale;

  /// Shows the app in [locale], or in the system language when null.
  Future<void> selectLanguage(Locale? locale) => setPreferredLocale(locale);

  /// Re-reads the service state and, while it runs, its version.
  ///
  /// This is what starts another check of the service connection; nothing else
  /// does, so a service that is down is reported once. See
  /// [NetworkBackend.retry].
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      await _backend.value.retry();
      if (_disposed) return;
      final state = await control.state();
      if (_disposed) return;
      serviceState.value = state;
      final version = state == ServiceState.running
          ? await _probeVersion()
          : null;
      // The probe can outlive both this controller and the signal it is
      // written to: neither may be touched once gone.
      if (_disposed || runningVersion.disposed) return;
      runningVersion.value = version;
    } catch (error) {
      if (!_disposed) showMessage(l10n.value.controllerCheckService('$error'));
    } finally {
      // Success or failure, the page may now show the real state.
      if (!_disposed) stateKnown.value = true;
    }
  }

  /// Switches to [kind], stopping the running networks once confirmed.
  Future<void> select(BackendKind kind) async {
    if (_disposed || busy.value || kind == this.kind.value) return;
    if (kind == BackendKind.service) {
      if (serviceState.value == ServiceState.rootRequired) {
        showMessage(l10n.value.controllerRootRequired);
        return;
      }
      if (serviceState.value != ServiceState.running &&
          serviceState.value != ServiceState.stopped) {
        showMessage(l10n.value.controllerInstallRequired);
        return;
      }
    }
    busy.value = true;
    try {
      if (!await _stopRunning(kind)) return;
      await backend_signals.switchBackend(kind);
    } catch (error) {
      if (!_disposed) showMessage(l10n.value.controllerStopNetworks('$error'));
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  /// Stops what the outgoing backend runs, so switching modes does not leave
  /// instances behind. False when the user cancels the switch.
  ///
  /// A backend that cannot answer is not an obstacle. Its networks belong to
  /// it, and refusing to switch would strand the user in a mode where every
  /// request fails, unable to get back out of it.
  Future<bool> _stopRunning(BackendKind kind) async {
    final backend = _backend.value;
    final Map<String, Instance> running;
    try {
      running = await backend.collect(networks.value);
    } on ServiceUnavailableException {
      // An unreachable service cannot say what it runs.
      return true;
    }
    if (running.isEmpty) return true;
    if (!await confirmStopNetworks(kind, running.length)) return false;
    try {
      await backend.stop([
        for (final instance in running.values) instance.network.networkName,
      ]);
    } on ServiceUnavailableException {
      // It stopped answering between the two calls: nothing is left to stop.
    }
    return true;
  }

  /// Installs or reinstalls the service, streaming the download's progress.
  Future<void> install() async {
    if (_disposed || busy.value) return;
    busy.value = true;
    installing.value = true;
    installProgress.value = null;
    try {
      await control.install(
        onProgress: (progress) {
          if (!_disposed) installProgress.value = progress;
        },
      );
    } catch (error) {
      if (!_disposed) showMessage(l10n.value.controllerServiceInstall('$error'));
    } finally {
      if (!_disposed) {
        installing.value = false;
        installProgress.value = null;
        busy.value = false;
        await refresh();
      }
    }
  }

  Future<void> start() =>
      _run(control.start, (error) => l10n.value.controllerServiceStart(error));

  Future<void> stop() =>
      _run(control.stop, (error) => l10n.value.controllerServiceStop(error));

  /// Removes the service and, when it was running the networks, the backend.
  Future<void> uninstall() => _run(() async {
    await control.uninstall();
    if (_backend.value.kind == BackendKind.service) {
      await backend_signals.switchBackend(BackendKind.ffi);
    }
  }, (error) => l10n.value.controllerServiceUninstall(error));

  /// Runs a service action, reports its failure through [failure], and
  /// refreshes the state afterwards either way.
  Future<void> _run(
    Future<void> Function() action,
    String Function(String error) failure,
  ) async {
    if (_disposed || busy.value) return;
    busy.value = true;
    try {
      await action();
    } catch (error) {
      if (!_disposed) showMessage(failure('$error'));
    } finally {
      if (!_disposed) {
        busy.value = false;
        await refresh();
      }
    }
  }

  /// The running service's version, from the injected probe or from its
  /// endpoint, retrying while a restarted service comes back up.
  late final Future<int?> Function() _probeVersion = _probe ?? _probeEndpoint;

  Future<int?> _probeEndpoint() async {
    for (var attempt = 0; attempt < _probeAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_probeInterval);
      try {
        final version = await runningServiceVersion(
          await IpcEndpoint.locate(control.dataDir),
        );
        if (version != null) return version;
      } catch (_) {
        // The service has not published its endpoint yet; try again.
      }
    }
    return null;
  }

  /// Frees every signal this controller created.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    serviceState.dispose();
    stateKnown.dispose();
    busy.dispose();
    runningVersion.dispose();
    installing.dispose();
    installProgress.dispose();
    outdated.dispose();
    for (final release in _disposers) {
      release();
    }
    _disposers.clear();
  }
}

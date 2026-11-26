import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/backend/service_version.dart';

import 'package:yukari_core/backend/ipc/ipc_client.dart';
import 'package:yukari_core/backend/service_backend.dart';

import '../../backend/system/service_control.dart';

import '../../signals/backend.dart' as backend_signals;
import '../../signals/locale.dart';
import '../../signals/networks.dart';
import '../../signals/settings.dart';

import '../signal_scope.dart';

part 'backend_service_actions.dart';
part 'interface_settings_actions.dart';

/// How often the version probe retries while a just-restarted service is
/// briefly unreachable, and how long it waits in between.
const _probeAttempts = 6;
const _probeInterval = Duration(milliseconds: 500);

/// The settings page's signals and actions: where the networks run, the state
/// of the background service, the interface language, and how the app starts.
class BackendSettingsController with SignalScope {
  BackendSettingsController({
    required this.showMessage,
    required this.confirmStopNetworks,
    ServiceControl? control,
    Future<int?> Function()? probeVersion,
    ReadonlySignal<NetworkBackend>? backend,
    bool? traySupport,
    bool? appVpn,
  }) : control = control ?? backend_signals.serviceControl,
       _probe = probeVersion,
       _backend = backend ?? backend_signals.backend,
       _injected = backend != null,
       _traySupported = traySupport,
       _appUsesSystemVpn = appVpn;

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

  /// The tray support this page reports, for tests; null reads the platform.
  final bool? _traySupported;

  /// The app-mode VPN this page reports, for tests; null reads the platform.
  final bool? _appUsesSystemVpn;
  bool _disposed = false;

  /// The service's installation and run state, as last refreshed.
  late final Signal<ServiceState> serviceState = own(ServiceState.unsupported);

  /// Whether [refresh] has answered yet, success or failure.
  ///
  /// [serviceState] starts at [ServiceState.unsupported], which is a wrong
  /// answer rather than an unknown one: the page shows a neutral loading form
  /// until this is true, so the real state replaces nothing the user is
  /// already reading.
  late final Signal<bool> stateKnown = own(false);

  /// Whether an action is in flight; gates every mutation.
  late final Signal<bool> busy = own(false);

  /// The version the running service reported, or null while unknown.
  late final Signal<int?> runningVersion = own(null);

  /// Whether an install is in flight, and how far its download is.
  late final Signal<bool> installing = own(false);
  late final Signal<double?> installProgress = own(null);

  /// The active backend's kind and connection status: the app-wide signals,
  /// or the injected backend's, which this controller owns.
  late final ReadonlySignal<BackendKind> kind = _injected
      ? derive(() => _backend.value.kind)
      : backend_signals.backendKind;
  late final ReadonlySignal<BackendStatus> status = _injected
      ? derive(() => _backend.value.status.value)
      : backend_signals.backendStatus;

  /// Whether the running service is older than the one this app ships.
  late final Computed<bool> outdated = derive(
    () => (runningVersion.value ?? serviceVersion) < serviceVersion,
  );

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

  /// The running service's version, from the injected probe or from its
  /// endpoint, retrying while a restarted service comes back up.
  late final Future<int?> Function() _probeVersion = _probe ?? _probeEndpoint;

  /// Frees every signal this controller created.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disposeSignals();
  }
}

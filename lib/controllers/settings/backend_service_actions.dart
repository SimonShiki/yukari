part of 'backend_settings_controller.dart';

extension BackendServiceActions on BackendSettingsController {
  /// Re-reads the service state and, while it runs, its version.
  ///
  /// The state is what the page shows, so it lands first: a service that has
  /// stopped answering must not hold the section spinning while the version
  /// probe retries. The version then arrives through [runningVersion].
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      // The connection reopens by itself when the app next needs it, so this
      // only makes the user's own refresh ask sooner. See [NetworkBackend.retry].
      await _backend.value.retry();
      if (_disposed) return;
      final state = await control.state();
      if (_disposed) return;
      serviceState.value = state;
      stateKnown.value = true;
      if (state == ServiceState.running) unawaited(_readVersion());
    } catch (error) {
      if (!_disposed) showMessage(l10n.value.controllerCheckService('$error'));
    } finally {
      // Success or failure, the page may now show the real state.
      if (!_disposed) stateKnown.value = true;
    }
  }

  /// Reads the running service's version, and reports it when one answers.
  Future<void> _readVersion() async {
    final int? version;
    try {
      version = await _probeVersion();
    } catch (error) {
      if (!_disposed) showMessage(l10n.value.controllerCheckService('$error'));
      return;
    }
    // The probe can outlive both this controller and the signal it is
    // written to: neither may be touched once gone.
    if (_disposed || runningVersion.disposed) return;
    runningVersion.value = version;
    // The initial refresh can land before a restarted service is listening.
    // The probe uses its own connection, so reconnect the active backend too.
    final backend = _backend.value;
    if (version != null &&
        backend.kind == BackendKind.service &&
        backend.status.value == BackendStatus.unavailable) {
      await backend.retry();
    }
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
      if (!_disposed) {
        showMessage(l10n.value.controllerServiceInstall('$error'));
      }
    } finally {
      if (!_disposed) {
        installing.value = false;
        installProgress.value = null;
        busy.value = false;
        await refresh();
      }
    }
  }

  Future<void> start() => _run(() async {
    if (await flushNetworkEdits()) await control.start();
  }, (error) => l10n.value.controllerServiceStart(error));

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
}

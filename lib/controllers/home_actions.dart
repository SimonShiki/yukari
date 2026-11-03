part of 'home_controller.dart';

/// The actions the home page invokes, and the controller's lifecycle.
extension HomeActions on HomeController {
  /// Refreshes while visible in the foreground, probing NAT on first use.
  /// Resuming starts a new traffic sample rather than averaging a hidden gap.
  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    _effect?.call();
    _effect = null;
    _timer?.cancel();
    _timer = null;
    _traffic = null;
    if (!active) return;
    _effect = effect(() {
      networks.value;
      status.value;
      untracked(() {
        refresh();
        checkServiceVersion();
      });
    });
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
    if (!_started) {
      _started = true;
      unawaited(detectNat());
    }
  }

  /// Re-collects the running instances into the shared store, falling back to
  /// the last known state when the backend cannot answer.
  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      Map<String, Instance>? collected;
      try {
        collected = await running.refreshInstances(_activeBackend.value);
      } catch (_) {
        // The backend's own status signal tells the user it is unreachable.
      }
      if (_disposed) return;
      // A failed collection measured nothing, so the last sample stands.
      final fresh = collected;
      if (fresh != null) batch(() => _measure(fresh));
    } finally {
      // Whatever happened, the next refresh must not be swallowed: release
      // the guard first, then tell the page the dashboard has data. A
      // disposed signal cannot be written, so a disposed controller only
      // resets the guard and stops refreshing anyway.
      _refreshing = false;
      if (!_disposed) refreshed.value = true;
    }
  }

  /// Detects the NAT type through STUN, if one is not already in flight.
  Future<void> detectNat() async {
    if (probing.value || _disposed) return;
    probing.value = true;
    try {
      final probe = await _probe();
      if (_disposed) return;
      _probeResult.value = probe;
    } catch (_) {
      if (_disposed) return;
      _probeResult.value = const NatProbe(
        publicAddress: null,
        natType: NatType.unknown,
      );
    } finally {
      if (!_disposed) probing.value = false;
    }
  }

  /// Reads the version of the background service, when one answers.
  Future<void> checkServiceVersion() async {
    int? version;
    try {
      version = await _probeServiceVersion();
    } catch (_) {
      version = null;
    }
    if (!_disposed) serviceVersion.value = version;
  }

  /// Releases the effect, the timer and every signal this controller created.
  void dispose() {
    if (_disposed) return;
    setActive(false);
    _disposed = true;
    for (final release in _disposers) {
      release();
    }
    _disposers.clear();
    _traffic = null;
  }
}

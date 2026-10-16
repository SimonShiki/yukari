part of 'home_controller.dart';

/// The actions the home page invokes, and the controller's lifecycle.
extension HomeActions on HomeController {
  /// Starts the refresh effect, the periodic refresh and one NAT detection.
  ///
  /// Idempotent: a second call keeps the effect and timer the first started.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _effect = effect(() {
      networks.value;
      status.value;
      untracked(() {
        refresh();
        checkServiceVersion();
      });
    });
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
    detectNat();
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
    _disposed = true;
    _effect?.call();
    _timer?.cancel();
    for (final release in _disposers) {
      release();
    }
    _disposers.clear();
    _traffic = null;
  }
}

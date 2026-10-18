part of 'android_system_ui.dart';

/// The network the tile boots: the last one booted while it is still saved,
/// else the first saved network, in display order.
String? bootNetworkId(Map<String, Network> networks, String? lastBooted) {
  if (lastBooted != null && networks.containsKey(lastBooted)) return lastBooted;
  return networks.isEmpty ? null : networks.keys.first;
}

/// What a tile tap or a notification action asks for, through the app's own
/// backend and service control.
extension _AndroidSystemUiActions on AndroidSystemUi {
  /// Runs [action]. A tile tap can arrive while the app is in the background,
  /// where it cannot show the VPN consent or start a foreground service; when
  /// that start is refused, the app is brought forward to retry it there.
  Future<void> _handleAction(String action, {required bool fromTile}) async {
    if (_disposed) return;
    switch (action) {
      case 'toggle':
        await _toggle(fromTile: fromTile);
      case 'stop':
        await _stop();
    }
  }

  /// Stops the running network, else boots the network [_bootLast] picks.
  Future<void> _toggle({required bool fromTile}) async {
    if (_kind == BackendKind.service) return _toggleService();
    final entry = await _currentInstance();
    if (entry != null) return _stopInstance(entry);
    await _bootLast(fromTile: fromTile);
  }

  /// Stops the running network, as the notification's Stop action asks.
  Future<void> _stop() async {
    if (_kind == BackendKind.service) return;
    final entry = await _currentInstance();
    if (entry != null) await _stopInstance(entry);
  }

  /// The running instance, after one collection when the store has not
  /// answered yet: the app may have just started to run this action.
  Future<MapEntry<String, Instance>?> _currentInstance() async {
    if (!running.instancesLoaded.peek()) await _refresh();
    return _runningEntry(running.instances.peek());
  }

  Future<void> _stopInstance(MapEntry<String, Instance> entry) async {
    try {
      await _backend.stop([entry.value.network.networkName]);
      // The store outlives this listener, so a settled stop shows at once.
      running.forgetInstances([entry.key]);
      await running.refreshInstances(_backend);
    } catch (_) {
      // A tile or notification tap has no UI to report to: the next
      // collection, or the app when it is next opened, shows the state.
    }
  }

  Future<void> _bootLast({required bool fromTile}) async {
    final networks = saved.networks.peek();
    final id = bootNetworkId(networks, _lastBooted);
    if (id == null) return;
    final network = networks[id]!;
    if (!await _mayStartSilently(network, fromTile: fromTile)) {
      // A background tap cannot show the VPN consent: bring the app forward
      // so the same toggle runs where the dialog and the error can show.
      if (fromTile && !_foreground) await _openApp();
      return;
    }
    try {
      await _backend.start(id, network);
      await running.refreshInstances(_backend);
    } catch (_) {
      // Android 12+ may refuse a foreground service started from the
      // background; retry the same toggle with the app in front.
      if (fromTile && !_foreground) await _openApp();
    }
  }

  /// Whether [network] may start now. A network the backend has no room for
  /// cannot start at all, so the tile leaves it alone; the VPN consent dialog
  /// needs the app in the foreground, so a background tile tap asks for the
  /// consent without a dialog, and the app is brought forward when that is not
  /// enough.
  Future<bool> _mayStartSilently(
    Network network, {
    required bool fromTile,
  }) async {
    if (!_backend.canStart(network, running.instances.peek().values)) {
      return false;
    }
    if (network.flags.noTun) return true;
    if (!fromTile || _foreground) {
      return await _backend.tunAccess(network) == TunAccess.granted;
    }
    return _vpnPermissionGranted();
  }

  /// Brings the app forward with the toggle pending. Best effort: Android may
  /// decline an activity start from the background, and then nothing happens.
  Future<void> _openApp() async {
    try {
      await _channel.invokeMethod<void>('openApp', {'action': 'toggle'});
    } catch (_) {
      // The tap has no other way to report; there is nothing left to do.
    }
  }

  /// Starts the background service, or stops it, and asks the backend for its
  /// state so the tile follows.
  Future<void> _toggleService() async {
    final ServiceState state;
    try {
      state = await serviceControl.state();
    } catch (_) {
      return;
    }
    try {
      switch (state) {
        case ServiceState.running:
          await serviceControl.stop();
        case ServiceState.stopped:
          await serviceControl.start();
        case ServiceState.unsupported:
        case ServiceState.rootRequired:
        case ServiceState.notInstalled:
          return;
      }
    } catch (_) {
      // Root was refused or the module failed; the settings page reports it.
      return;
    }
    await _backend.retry();
  }

  /// Collects the running instances once, following the pages' own cadence.
  Future<void> _refresh() async {
    try {
      await running.refreshInstances(_backend);
    } catch (_) {
      // The backend's status signal already reports an unreachable service.
    }
  }

  /// Remembers the network the tile boots next, which the store keeps.
  void _rememberBooted(String? id) {
    if (id == null || id == _lastBooted) return;
    _lastBooted = id;
    unawaited(_prefs?.setString(AndroidSystemUi._lastBootedKey, id));
  }
}

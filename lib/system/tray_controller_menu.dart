part of 'tray_controller.dart';

/// The tray menu's data: what is saved, running and reachable right now.
extension _TrayMenuData on TrayController {
  /// The menu for what is saved, running and reachable right now.
  ///
  /// The network rows are top-level, under a disabled "Networks" section
  /// label: a submenu row would draw its arrow over the long label text.
  TrayMenu _buildMenu() {
    final strings = l10n.value;
    final instances = running.instances.value;
    final networks = saved.networks.value;
    final canAct = _backend.value.status.value == BackendStatus.ready;
    _measureTraffic(instances);
    return TrayMenu([
      TrayMenuItem(
        id: 'open',
        label: strings.trayOpen,
        onSelected: platform.showWindow,
      ),
      const TrayMenuSeparator(),
      TrayMenuItem(id: 'networks', label: strings.navNetworks, enabled: false),
      if (networks.isEmpty)
        TrayMenuItem(
          id: 'no-networks',
          label: strings.trayNoNetworks,
          enabled: false,
        )
      else
        for (final MapEntry(key: id, value: network) in networks.entries)
          _networkItem(id, network, instances, canAct: canAct),
      const TrayMenuSeparator(),
      TrayMenuItem(
        id: 'exit',
        label: strings.trayExit,
        onSelected: () => unawaited(platform.quit()),
      ),
    ]);
  }

  TrayMenuItem _networkItem(
    String id,
    Network network,
    Map<String, Instance> instances, {
    required bool canAct,
  }) {
    final instance = instances[id];
    final running = instance?.status == InstanceStatus.running;
    return TrayMenuItem(
      id: 'network:$id',
      label: trayNetworkLabel(
        network.networkName,
        peers: running ? l10n.value.trayPeers(instance!.memberCount) : null,
        traffic: running ? _samples[id] : null,
      ),
      checked: running,
      enabled: canAct,
      onSelected: () => unawaited(_toggle(id, !_networks.isRunning(id))),
    );
  }

  /// Measures the traffic of every running instance into the samples.
  void _measureTraffic(Map<String, Instance> instances) {
    for (final MapEntry(:key, :value) in instances.entries) {
      if (value.status != InstanceStatus.running) continue;
      _samples[key] = measureTraffic({key: value}, _samples[key]);
    }
    _samples.removeWhere((id, _) => instances[id] == null);
  }

  /// Starts or stops the network behind a menu row.
  Future<void> _toggle(String id, bool start) async {
    if (!await _networks.toggle(id, start)) {
      // A TUN device needs the user, and only the window can ask; bring it up
      // instead of failing silently in the tray.
      platform.showWindow();
    }
  }

  /// Coalesces a burst of signal updates into one menu rebuild.
  void _scheduleMenuUpdate(TrayMenu menu) {
    _pendingMenu = menu;
    if (_menuScheduled) return;
    _menuScheduled = true;
    scheduleMicrotask(() {
      _menuScheduled = false;
      final pending = _pendingMenu;
      _pendingMenu = null;
      if (_disposed || pending == null) return;
      unawaited(platform.setMenu(pending));
    });
  }
}

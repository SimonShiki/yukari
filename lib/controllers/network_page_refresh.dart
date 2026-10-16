part of 'network_page_controller.dart';

/// The list's refresh cycle, its foreground timer and the row data it derives.
extension NetworkPageRefresh on NetworkPageController {
  /// Starts the effect that keeps the selection pointing at a saved network.
  void start() {
    _cleanups.add(
      effect(() {
        final ids = saved.networks.value.keys.toList();
        final selected = selectedId.peek();
        if (ids.isEmpty) {
          if (selected != null) selectedId.value = null;
        } else if (selected == null || !ids.contains(selected)) {
          selectedId.value = ids.first;
        }
      }),
    );
  }

  /// Refreshes while the list is visible in the foreground, and keeps the
  /// periodic refresh running for exactly as long as something runs.
  void setActive(bool active) {
    if (active == _active || _disposed) return;
    _active = active;
    if (!active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    unawaited(refresh());
  }

  /// Collects every running instance, and records the events it reports.
  Future<void> refresh() async {
    if (_disposed || refreshing.peek()) return;
    refreshing.value = true;
    final snapshot = saved.networks.value;
    try {
      final collected = await activeBackend.collect(snapshot);
      for (final MapEntry(:key, :value) in collected.entries) {
        recordInstanceEvents(key, value.events);
      }
      batch(() {
        instances.value = Map.unmodifiable(collected);
        loaded.value = true;
        refreshError.value = null;
        _dropResolved(collected);
      });
    } catch (error) {
      // The backend's own status tells the user it is unreachable; the last
      // known state stays on screen.
      refreshError.value = l10n.value.controllerRefresh('$error');
    } finally {
      refreshing.value = false;
      _syncTimer();
    }
  }

  /// The periodic refresh only exists while the list is active and something
  /// runs, so an idle page leaves no timer behind.
  void _syncTimer() {
    final running = _active && instances.peek().isNotEmpty;
    if (!running) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  /// Drops the markers of start/stop requests that the backend settled.
  void _dropResolved(Map<String, Instance> collected) {
    final resolved = {
      for (final MapEntry(:key, :value) in transitions.peek().entries)
        if (switch (value) {
          NetworkTransition.starting => collected.containsKey(key),
          NetworkTransition.stopping => !collected.containsKey(key),
          // A failed start clears once the instance is actually up.
          NetworkTransition.failed => collected.containsKey(key),
        })
          key,
    };
    if (resolved.isEmpty) return;
    transitions.value = {
      for (final MapEntry(:key, :value) in transitions.peek().entries)
        if (!resolved.contains(key)) key: value,
    };
  }

  NetworkCardData _card(
    String id,
    Network network, {
    required bool limitReached,
    required bool settled,
  }) {
    final transition = transitions.value[id];
    final running = instances.value.containsKey(id);
    final busy =
        deleting.value.contains(id) ||
        transition == NetworkTransition.starting ||
        transition == NetworkTransition.stopping;
    final status = switch (transition) {
      NetworkTransition.starting => InstanceStatus.starting,
      NetworkTransition.stopping => InstanceStatus.stopping,
      NetworkTransition.failed => InstanceStatus.failed,
      null => settled
          ? instances.value[id]?.status ?? InstanceStatus.stopped
          : InstanceStatus.unknown,
    };
    return NetworkCardData(
      id: id,
      name: network.networkName,
      status: status,
      running: running,
      busy: busy,
      onOpen: () => openDetail(id),
      onEdit: () => unawaited(edit(id)),
      onLog: () => unawaited(log(id)),
      onDelete: () => delete(id),
      onToggle: busy || !settled || limitReached
          ? null
          : (start) => toggle(id, start),
    );
  }
}

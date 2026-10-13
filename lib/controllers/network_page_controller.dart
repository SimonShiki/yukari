import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

import '../backend/backend.dart';
import '../bindings/easytier_ffi_native.dart' as native;
import '../models/models.dart';
import 'network_instance_controller.dart';
import '../signals/backend.dart';
import '../signals/instance_logs.dart';
import '../signals/networks.dart';
import '../utils/easytier_config_parser.dart';
import '../utils/validator.dart';
import '../widgets/network_card/network_card_data.dart';

part 'network_page_actions.dart';

class NetworkPageController {
  NetworkPageController({
    required this.navigate,
    required this.showMessage,
    required this.confirmDelete,
    required this.showTunPermissionWarning,
    NetworkBackend? backend,
    this.refreshInterval = const Duration(seconds: 10),
  }) : _injected = backend {
    _unsubscribe = effect(() {
      networks.value;
      _backend; // Refresh when the user switches backends too.
      if (_active) unawaited(refresh());
    });
  }

  final void Function(String route, String? id) navigate;
  final ValueChanged<String> showMessage;
  final Future<bool> Function(Network) confirmDelete;
  final Future<void> Function(Network) showTunPermissionWarning;
  final Duration refreshInterval;
  final Map<String, Key> _keys = {};

  /// The backend to use instead of the active one, such as in tests.
  final NetworkBackend? _injected;
  late final void Function() _unsubscribe;
  Timer? _timer;
  bool _active = false;
  bool _disposed = false;

  final instances = signal<Map<String, Instance>>({});
  final transitions = signal<Map<String, InstanceStatus>>({});
  final deleting = signal<Set<String>>({});
  final refreshing = signal(false);
  final loaded = signal(false);
  final refreshError = signal<String?>(null);
  final selectedNetwork = signal<String?>(null);

  /// Tab of the selected running network, when it is shown beside the list.
  /// The shown page keeps it in sync with the user's own tab switches.
  final selectedTab = signal(InstanceTab.peers);

  late final error = computed(() => refreshError.value);
  late final selectedNetworkRunning = computed(
    () =>
        selectedNetwork.value != null &&
        instances.value.containsKey(selectedNetwork.value),
  );

  late final cards = computed(() {
    final saved = networks.value;
    _keys.removeWhere((key, _) => !saved.containsKey(key));

    // Auto-select first network if none selected and cards exist
    if (saved.isNotEmpty && selectedNetwork.value == null) {
      selectedNetwork.value = saved.keys.first;
    } else if (saved.isEmpty) {
      selectedNetwork.value = null;
    } else if (selectedNetwork.value != null &&
        !saved.containsKey(selectedNetwork.value)) {
      // Selected network was deleted, select first available
      selectedNetwork.value = saved.keys.first;
    }

    return [for (final entry in saved.entries) _card(entry.key, entry.value)];
  });

  late final hasRunningNetwork = computed(() => instances.value.isNotEmpty);

  NetworkBackend get _backend => _injected ?? backend.value;

  Key keyForIndex(int index) =>
      _keys.putIfAbsent(networks.value.keys.elementAt(index), UniqueKey.new);

  void selectNetwork(String id, {InstanceTab tab = InstanceTab.peers}) {
    batch(() {
      selectedNetwork.value = id;
      selectedTab.value = tab;
    });
  }

  NetworkCardData _card(String id, Network network) {
    final instance = instances.value[id];
    final transition = transitions.value[id];
    final busy =
        deleting.value.contains(id) ||
        transition == InstanceStatus.starting ||
        transition == InstanceStatus.stopping;
    final running = instance != null;

    // Some backends run a limited number of instances, like Android's VPN.
    final limitReached =
        !running &&
        switch (_backend.maxInstances) {
          final limit? => instances.value.length >= limit,
          null => false,
        };

    return NetworkCardData(
      id: id,
      name: network.networkName,
      status:
          transition ??
          (error.value != null || !loaded.value
              ? InstanceStatus.unknown
              : instance?.status ?? InstanceStatus.stopped),
      running: running,
      busy: busy,
      onOpen: () => selectNetwork(id),
      onEdit: () => edit(id),
      onLog: () => log(id),
      onDelete: () => delete(id),
      onToggle: busy || error.value != null || !loaded.value || limitReached
          ? null
          : (value) => toggle(id, value),
    );
  }

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    _timer?.cancel();
    if (active) {
      unawaited(refresh());
      _timer = Timer.periodic(refreshInterval, (_) {
        if (hasRunningNetwork.peek()) {
          unawaited(refresh());
        }
      });
    }
  }

  Future<void> refresh() async {
    if (_disposed || refreshing.value) return;
    refreshing.value = true;
    try {
      final snapshot = Map<String, Network>.of(networks.value);
      final newInstances = await _backend.collect(snapshot);
      if (_disposed) return;
      for (final MapEntry(:key, :value) in newInstances.entries) {
        recordInstanceEvents(key, value.events);
      }
      instances.value = newInstances;
      loaded.value = true;
      refreshError.value = null;
      transitions.value.removeWhere(
        (name, status) =>
            (status == InstanceStatus.starting &&
                newInstances.containsKey(name)) ||
            (status == InstanceStatus.stopping &&
                !newInstances.containsKey(name)) ||
            (status == InstanceStatus.failed &&
                newInstances[name]?.status == InstanceStatus.running),
      );
      transitions.set(transitions.value);
    } catch (e) {
      if (!_disposed) {
        refreshError.value = 'Failed to refresh networks: $e';
      }
    } finally {
      refreshing.value = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _unsubscribe();
  }
}

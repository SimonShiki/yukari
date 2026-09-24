import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

import '../bindings/easytier_ffi_native.dart' as native;
import '../models/instance.dart';
import '../models/network.dart';
import '../signals/networks.dart';
import '../utils/easytier_config_parser.dart';
import '../utils/network_runner_android.dart';
import '../utils/tun_helper.dart';
import '../widgets/network_card/network_card_data.dart';

part 'network_page_actions.dart';

class NetworkPageController {
  NetworkPageController({
    required this.navigate,
    required this.showMessage,
    required this.confirmDelete,
    required this.showLog,
    required this.showTunPermissionWarning,
    FutureOr<Map<String, Instance>> Function(Map<String, Network>)? collect,
    Future<void> Function(Network)? run,
    FutureOr<void> Function(List<String>)? stop,
    this.refreshInterval = const Duration(seconds: 10),
  }) : _collect = collect ?? native.collectNetworkInfos,
       _run = run ?? (Platform.isAndroid
           ? AndroidNetworkRunner.runNetworkWithVpn
           : native.runNetworkInstance),
       _stop = stop ?? native.deleteNetworkInstances {
    _unsubscribe = effect(() {
      networks.value;
      if (_active) unawaited(refresh());
    });
  }

  final void Function(String route, String? name) navigate;
  final ValueChanged<String> showMessage;
  final Future<bool> Function(Network) confirmDelete;
  final ValueChanged<Instance> showLog;
  final Future<bool> Function(Network) showTunPermissionWarning;
  final Duration refreshInterval;
  final Map<String, Key> _keys = {};
  final FutureOr<Map<String, Instance>> Function(Map<String, Network>) _collect;
  final Future<void> Function(Network) _run;
  final FutureOr<void> Function(List<String>) _stop;
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

  late final error = computed(() => refreshError.value);
  late final selectedNetworkRunning = computed(() =>
      selectedNetwork.value != null && instances.value.containsKey(selectedNetwork.value));

  late final cards = computed(() {
    final saved = networks.value;
    _keys.removeWhere((key, _) => !saved.containsKey(key));

    // Auto-select first network if none selected and cards exist
    if (saved.isNotEmpty && selectedNetwork.value == null) {
      selectedNetwork.value = saved.keys.first;
    } else if (saved.isEmpty) {
      selectedNetwork.value = null;
    } else if (selectedNetwork.value != null && !saved.containsKey(selectedNetwork.value)) {
      // Selected network was deleted, select first available
      selectedNetwork.value = saved.keys.first;
    }

    return [for (final entry in saved.entries) _card(entry.key, entry.value)];
  });

  Key keyForIndex(int index) =>
      _keys.putIfAbsent(networks.value.keys.elementAt(index), UniqueKey.new);

  void selectNetwork(String id) {
    if (selectedNetwork.value != id) {
      selectedNetwork.value = id;
    }
  }

  NetworkCardData _card(String name, Network network) {
    final instance = instances.value[name];
    final transition = transitions.value[name];
    final busy =
        deleting.value.contains(name) ||
        transition == InstanceStatus.starting ||
        transition == InstanceStatus.stopping;
    final running = instance != null;
    return NetworkCardData(
      name: network.networkName,
      status:
          transition ??
          (error.value != null || !loaded.value
              ? InstanceStatus.unknown
              : instance?.status ?? InstanceStatus.stopped),
      running: running,
      busy: busy,
      onOpen: () => selectNetwork(name),
      onEdit: () => edit(name),
      onLog: () => log(name),
      onDelete: () => delete(name),
      onToggle: busy || error.value != null || !loaded.value
          ? null
          : (value) => toggle(name, value),
    );
  }

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    _timer?.cancel();
    if (active) {
      unawaited(refresh());
      _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    }
  }

  Future<void> refresh() async {
    if (_disposed || refreshing.value) return;
    refreshing.value = true;
    try {
      final snapshot = Map<String, Network>.of(networks.value);
      final newInstances = await _collect(snapshot);
      if (_disposed) return;
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

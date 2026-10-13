import 'dart:async';

import 'package:signals/signals.dart';

import '../backend/backend.dart';
import '../models/instance.dart';
import '../models/log_entry.dart';
import '../signals/backend.dart';
import '../signals/instance_logs.dart';
import '../signals/networks.dart';

enum InstanceTab { peers, logs }

enum LogFilter {
  all,
  errors,
  peers,
  connections,
  listeners;

  bool matches(LogEntry entry) => switch (this) {
    all => true,
    errors => entry.severity == LogSeverity.error,
    peers => entry.category == LogCategory.peer,
    connections => entry.category == LogCategory.connection,
    listeners => entry.category == LogCategory.listener,
  };
}

/// Follows the running instance of the saved network [id].
class NetworkInstanceController {
  NetworkInstanceController({
    required this.id,
    NetworkBackend? backend,
    this.refreshInterval = const Duration(seconds: 2),
  }) : _injected = backend,
       logs = instanceLogs(id);

  final String id;
  final Duration refreshInterval;

  /// The backend to use instead of the active one, such as in tests.
  final NetworkBackend? _injected;
  final ReadonlySignal<List<LogEntry>> logs;
  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  late final network = computed(() => networks.value[id]);
  final instance = signal<Instance?>(null);
  final loaded = signal(false);
  final filter = signal(LogFilter.all);

  /// Expanded entries, tracked by identity so they survive new arrivals.
  final expanded = signal<Set<LogEntry>>(const {});

  late final visibleLogs = computed(() {
    final filter = this.filter.value;
    final logs = this.logs.value;
    return filter == LogFilter.all
        ? logs
        : logs.where(filter.matches).toList(growable: false);
  });

  late final counts = computed(() {
    final logs = this.logs.value;
    return {
      for (final filter in LogFilter.values)
        filter: filter == LogFilter.all
            ? logs.length
            : logs.where(filter.matches).length,
    };
  });

  void toggleExpanded(LogEntry entry) {
    final next = Set.of(expanded.value);
    if (!next.remove(entry)) next.add(entry);
    expanded.value = next;
  }

  void setActive(bool active) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (!active) return;
    unawaited(refresh());
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final network = this.network.peek();
    if (_disposed || _refreshing || network == null) return;
    _refreshing = true;
    try {
      final current = (await (_injected ?? backend.value).collect({
        id: network,
      }))[id];
      if (_disposed) return;
      if (current != null) recordInstanceEvents(id, current.events);
      instance.value = current;
    } catch (_) {
      // Keep the last known state; the next tick retries.
    } finally {
      _refreshing = false;
      if (!_disposed) loaded.value = true;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    network.dispose();
    visibleLogs.dispose();
    counts.dispose();
  }
}

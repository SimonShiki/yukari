import 'dart:async';

import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/log_entry.dart';
import 'package:yukari_core/models/models.dart';
import '../signals/backend.dart' as backends;
import '../signals/instance_logs.dart';
import '../signals/instances.dart' as running;
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../widgets/peer_card/peer_card_data.dart';

part 'network_instance_logs.dart';

/// The tabs of the instance page, and the tab a route asks for.
enum InstanceTab { peers, logs }

/// The log categories the instance page can filter by.
enum LogFilter { all, errors, peers, connections, listeners }

/// One network's instance page: its peers, and its recorded events.
class NetworkInstanceController {
  NetworkInstanceController({
    required this.id,
    this.initialTab = InstanceTab.peers,
    Signal<InstanceTab>? tab,
    NetworkBackend? backend,
    this.refreshInterval = const Duration(seconds: 2),
  }) : _tab = tab,
       _injected = backend {
    // The route's tab, or the list page's, drives the page's own selection.
    if (tab != null) {
      _cleanups.add(
        effect(() {
          final requested = tab.value;
          if (selectedTab.peek() != requested) selectedTab.value = requested;
        }),
      );
    }
  }

  /// Key of the network in the saved network collection.
  final String id;

  /// The tab the route asks for.
  final InstanceTab initialTab;
  final Signal<InstanceTab>? _tab;
  final Duration refreshInterval;
  final NetworkBackend? _injected;

  /// The tab the page shows. The page syncs its `TabController` with this, and
  /// calls [selectTab] when the user switches tabs.
  late final Signal<InstanceTab> selectedTab = signal(initialTab);

  /// The saved network, or null once it is deleted.
  late final ReadonlySignal<Network?> network = computed(
    () => saved.networks.value[id],
  );

  /// Whether the saved network is gone, which replaces the whole page.
  late final ReadonlySignal<bool> missing = computed(
    () => saved.networks.value[id] == null,
  );

  /// The network's name, for the app bar.
  late final ReadonlySignal<String> name = computed(
    () => saved.networks.value[id]?.networkName ?? '',
  );

  /// The instance as of the last collection, or null while it is not running.
  late final ReadonlySignal<Instance?> instance = computed(
    () => running.instances.value[id],
  );

  /// Whether the backend answered at least once: the instance pane keeps its
  /// loading indicator up until the first successful collection.
  ReadonlySignal<bool> get loaded => running.instancesLoaded;

  /// Whether an instance of this network is running.
  late final ReadonlySignal<bool> isRunning = computed(
    () => instance.value != null,
  );

  /// The log category the logs tab shows.
  final Signal<LogFilter> filter = signal(LogFilter.all);

  /// The raw lines of the expanded log entries.
  final Signal<Set<String>> expanded = signal(const {});

  /// Every recorded event of this network, newest first.
  ReadonlySignal<List<LogEntry>> get logs => instanceLogs(id);

  /// The events the selected filter shows, newest first.
  late final ReadonlySignal<List<LogEntry>> visibleLogs = computed(
    () => _matching(filter.value),
  );

  /// This device first, then the peers in EasyTier order.
  late final ReadonlySignal<List<PeerCardData>> peerCards = computed(() {
    final current = instance.value;
    if (current == null) return const [];
    final strings = l10n.value;
    return [
      if (current.myself case final self?)
        PeerCardData.fromSelf(self, strings),
      for (final peer in current.peers) PeerCardData.fromPeer(peer, strings),
    ];
  });

  final List<void Function()> _cleanups = [];
  final _counts = <LogFilter, Computed<int>>{};
  bool _refreshing = false;
  bool _disposed = false;
  bool _active = false;
  Timer? _timer;

  NetworkBackend get _backend => _injected ?? backends.backend.value;

  /// Selects [tab], which the route's tab signal follows when it has one.
  void selectTab(InstanceTab tab) {
    if (selectedTab.value == tab && _tab?.value == tab) return;
    selectedTab.value = tab;
    if (_tab != null && _tab.value != tab) _tab.value = tab;
  }

  /// Runs the periodic refresh only while the page is in the foreground.
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    _timer?.cancel();
    _timer = null;
    if (!active) return;
    unawaited(refresh());
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  /// Collects every running instance into the shared store, swallowing
  /// failures: the last known state stays on screen and the next tick retries.
  Future<void> refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    try {
      if (network.value != null) await running.refreshInstances(_backend);
    } catch (_) {
      // Keep what is on screen; the next tick retries.
    } finally {
      _refreshing = false;
    }
  }

  void dispose() {
    _disposed = true;
    _active = false;
    _timer?.cancel();
    _timer = null;
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
    for (final count in _counts.values) {
      count.dispose();
    }
    _counts.clear();
    // [loaded] lives in the shared store, which outlives this controller.
    for (final signal in <ReadonlySignal<Object?>>[
      network,
      missing,
      name,
      selectedTab,
      instance,
      isRunning,
      filter,
      expanded,
      visibleLogs,
      peerCards,
    ]) {
      signal.dispose();
    }
  }

}

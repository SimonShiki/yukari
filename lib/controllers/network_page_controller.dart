import 'dart:async';

import 'package:signals/signals.dart';

import '../backend/backend.dart';
import '../models/models.dart';
import '../signals/backend.dart' as backends;
import '../signals/instance_logs.dart';
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../widgets/network_card/network_card_data.dart';
import 'network_instance_controller.dart';
import 'network_page_actions.dart';

export 'network_page_actions.dart';

part 'network_page_refresh.dart';

/// Where a network is in the middle of a start or stop request.
enum NetworkTransition { starting, stopping, failed }

/// Navigates: to the absolute [route] when [id] is null, else to the named
/// [route] with that network [id].
typedef NetworkNavigator = void Function(String route, String? id);

/// A config file the user picked to import.
class PickedConfig {
  const PickedConfig({required this.name, required this.content});

  /// File name, as a failed import reports it.
  final String name;

  /// The file's TOML content.
  final String content;
}

/// Controller of the networks list, and of the editor it shows beside it on
/// wide windows.
///
/// It owns every signal the page reads as a small primitive ([refreshing],
/// [loaded], [refreshError], an instance per id in [instances], a transition per
/// id in [transitions]) and derives the row data the list binds in [cards]. The
/// actions it invokes with live in `network_page_actions.dart`.
class NetworkPageController {
  NetworkPageController({
    required this.navigate,
    required this.showMessage,
    required this.confirmDelete,
    required this.showTunPermissionWarning,
    this.backend,
    this.refreshInterval = const Duration(seconds: 10),
    this.isWide,
    this.invalidInput,
    this.confirmDiscardDialog,
    this.pickConfig,
    this.validateConfig,
  });

  final NetworkNavigator navigate;
  final void Function(String message) showMessage;
  final Future<bool> Function(Network network) confirmDelete;
  final Future<void> Function(Network network) showTunPermissionWarning;

  /// Whether the list is showing beside a detail pane, so its rows act on the
  /// pane instead of navigating. The page injects this from its layout.
  final bool Function()? isWide;

  /// A backend to use instead of the app's active one, for tests.
  final NetworkBackend? backend;
  final Duration refreshInterval;

  /// Whether the editor the list would leave holds invalid input. The page
  /// looks the editor's live form up.
  final bool Function()? invalidInput;

  /// Asks the user before invalid input is discarded; the page shows the
  /// dialog. Null means every change is allowed.
  final Future<bool> Function()? confirmDiscardDialog;

  /// Picks a config file to import, for tests. Null uses the file picker.
  final Future<PickedConfig?> Function()? pickConfig;

  /// Validates a config before it is parsed, for tests. Null uses EasyTier.
  final void Function(String config)? validateConfig;

  /// Running instances, keyed by network id, as of the last refresh.
  final Signal<Map<String, Instance>> instances = signal(const {});

  /// Start/stop requests that have not settled yet, keyed by network id.
  final Signal<Map<String, NetworkTransition>> transitions = signal(const {});

  /// Ids whose deletion is in progress.
  final Signal<Set<String>> deleting = signal(const {});

  /// Whether a refresh is running; the refresh action is disabled meanwhile.
  final Signal<bool> refreshing = signal(false);

  /// Whether the backend answered at least once.
  final Signal<bool> loaded = signal(false);

  /// Why the last refresh failed, or null.
  final Signal<String?> refreshError = signal(null);

  /// The network the detail pane shows, or null when none is selected.
  final Signal<String?> selectedId = signal(null);

  /// The tab the detail pane's instance page shows.
  final Signal<InstanceTab> instanceTab = signal(InstanceTab.peers);

  /// Whether the selected network is running, which is what the detail pane
  /// decides between the instance page and the editor.
  late final ReadonlySignal<bool> selectionRunning = computed(
    () => instances.value.containsKey(selectedId.value),
  );

  /// The rows of the list, in display order.
  late final ReadonlySignal<List<NetworkCardData>> cards = computed(() {
    final limit = activeBackend.maxInstances;
    final limitReached = limit != null && instances.value.length >= limit;
    final settled = loaded.value && refreshError.value == null;
    return [
      for (final MapEntry(:key, value: network) in saved.networks.value.entries)
        _card(key, network, limitReached: limitReached, settled: settled),
    ];
  });

  final List<void Function()> _cleanups = [];
  bool _disposed = false;
  bool _active = false;
  Timer? _timer;

  /// The backend to act on: the injected one, else the app's active one.
  NetworkBackend get activeBackend => backend ?? backends.backend.value;

  /// Whether this platform and build can run the background service.
  bool get serviceSupported => backends.serviceControl.supported;

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// Whether the list is visible in the foreground, so its timer runs.
  bool get active => _active;

  /// Asks before discarding invalid input, when the page supplied a dialog.
  Future<bool> confirmDiscard() async =>
      await confirmDiscardDialog?.call() ?? true;

  void dispose() {
    _disposed = true;
    _active = false;
    _timer?.cancel();
    _timer = null;
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
    for (final signal in <ReadonlySignal<Object?>>[
      instances,
      transitions,
      deleting,
      refreshing,
      loaded,
      refreshError,
      selectedId,
      instanceTab,
      selectionRunning,
      cards,
    ]) {
      signal.dispose();
    }
  }

}

import 'dart:async';

import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/models.dart';
import '../signals/backend.dart' as backends;
import '../signals/instances.dart' as running;
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../widgets/network_card/network_card_data.dart';
import 'multi_selection.dart';
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
/// It owns the signals the page reads as a small primitive ([refreshing],
/// [refreshError], a transition per id in [transitions]) and derives the row
/// data the list binds in [cards]. The running instances and whether the
/// backend answered come from the shared [instances] store, which every page
/// sees. The actions it invokes with live in `network_page_actions.dart`.
class NetworkPageController {
  NetworkPageController({
    required this.navigate,
    required this.showMessage,
    required this.confirmDelete,
    required this.showTunPermissionWarning,
    this.backend,
    this.refreshInterval = const Duration(seconds: 10),
    this.pushRoute,
    this.isWide,
    this.invalidInput,
    this.confirmDiscardDialog,
    this.pickConfig,
    this.saveExportFile,
    this.validateConfig,
  });

  final NetworkNavigator navigate;
  final void Function(String message) showMessage;

  /// Asks before [networks] are deleted: one question for the whole batch, so
  /// a single delete and a selection are confirmed the same way.
  final Future<bool> Function(List<Network> networks) confirmDelete;
  final Future<void> Function(Network network) showTunPermissionWarning;

  /// Opens an absolute route above the shell, so its back button returns to
  /// this page. Defaults to [navigate]; the page points it at `context.push`.
  final void Function(String route)? pushRoute;

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

  /// Writes an exported config, for tests. Null uses the save dialog; it
  /// returns false when the user cancelled the dialog.
  final Future<bool> Function(String name, String content)? saveExportFile;

  /// Validates a config before it is parsed, for tests. Null uses EasyTier.
  final void Function(String config)? validateConfig;

  /// Running instances, keyed by network id, from the shared store.
  ReadonlySignal<Map<String, Instance>> get instances => running.instances;

  /// Start/stop requests that have not settled yet, keyed by network id.
  final Signal<Map<String, NetworkTransition>> transitions = signal(const {});

  /// Ids whose deletion is in progress.
  final Signal<Set<String>> deleting = signal(const {});

  /// Whether a refresh is running; the refresh action is disabled meanwhile.
  final Signal<bool> refreshing = signal(false);

  /// Whether the backend answered at least once: the cards stay unknown until
  /// the first successful collection.
  ReadonlySignal<bool> get loaded => running.instancesLoaded;

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
    final settled = loaded.value && refreshError.value == null;
    return [
      for (final MapEntry(:key, value: network) in saved.networks.value.entries)
        _card(key, network, settled: settled),
    ];
  });

  /// The ids the list can select, in display order.
  late final ReadonlySignal<List<String>> selectableIds = computed(
    () => [for (final card in cards.value) card.id],
  );

  /// The gallery-style selection the list runs, entered from the app bar.
  late final MultiSelection selection = MultiSelection(
    selectable: selectableIds,
  );

  /// Whether there is a network to select, so the app bar offers selection.
  bool get canSelect => cards.value.isNotEmpty;

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
    selection.dispose();
    // [instances] and [loaded] live in the shared store, which outlives this
    // controller; everything else was created here.
    for (final signal in <ReadonlySignal<Object?>>[
      transitions,
      deleting,
      refreshing,
      refreshError,
      selectedId,
      instanceTab,
      selectionRunning,
      selectableIds,
      cards,
    ]) {
      signal.dispose();
    }
  }

}

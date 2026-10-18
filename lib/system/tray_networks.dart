import 'package:signals/signals.dart';

import '../backend/backend.dart';
import '../models/models.dart';
import '../signals/instance_logs.dart' show clearInstanceLogs;
import '../signals/instances.dart' as running;
import '../signals/networks.dart' as saved;

/// The tray's start and stop actions, on the shared stores and the active
/// backend.
///
/// It keeps no state of its own. Whether a network runs is read from the
/// instances store at the moment of the click, and a start or stop sends the
/// same backend request a page sends, then collects that store again. Every
/// page binds to the same store, so the tray cannot drift from it.
///
/// A [NetworkPageController] is deliberately not used: one made for the tray
/// would own a second `transitions`/`refreshError` state, and in service mode
/// one failed collection latches that error, silently swallowing every later
/// tray click while the window's own controller keeps working. The controller
/// also keeps the request in flight while the network starts, and that block
/// would be private to the tray.
final class TrayNetworkActions {
  TrayNetworkActions(this._backend);

  final ReadonlySignal<NetworkBackend> _backend;

  /// Whether [id] is running, from the shared instances store.
  bool isRunning(String id) =>
      running.instances.peek()[id]?.status == InstanceStatus.running;

  /// Starts [id] when [start], else stops it, then collects the store again so
  /// every page and the menu show the settled state.
  ///
  /// Returns false when the start needs the user: TUN access can only be
  /// granted from the window.
  Future<bool> toggle(String id, bool start) async {
    final network = saved.networks.peek()[id];
    if (network == null) return true;
    final backend = _backend.value;
    if (running.instances.peek().containsKey(id) == start) return true;
    if (start) {
      final limit = backend.maxInstances;
      if (limit != null && running.instances.peek().length >= limit) {
        return true;
      }
      if (await backend.tunAccess(network) != TunAccess.granted) return false;
      clearInstanceLogs(id);
      try {
        await backend.start(id, network);
      } catch (_) {
        // The collection below says what the backend ended up running.
      }
    } else {
      try {
        await backend.stop([network.networkName]);
        // The store outlives this click, so a settled stop shows at once.
        running.forgetInstances([id]);
      } catch (_) {
        // A stop that failed leaves the instance running; the collection shows
        // it rather than guessing.
      }
    }
    await refresh();
    return true;
  }

  /// Collects the running instances into the shared store.
  Future<void> refresh() async {
    try {
      await running.refreshInstances(_backend.value);
    } catch (_) {
      // The backend's status signal already reports an unreachable service;
      // the last known state stays.
    }
  }
}

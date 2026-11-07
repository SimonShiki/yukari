import 'dart:async';

import 'package:signals/signals.dart';

import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../utils/optimistic_store.dart';

part 'network_edits.dart';

/// Private backing signal for the global network collection.
/// Use [networks] for readonly access.
final Signal<Map<String, Network>> _networks = signal(
  const <String, Network>{},
);

/// Every saved network, keyed by id, in an unmodifiable map.
///
/// [init] loads the persisted networks once at startup. [addNetwork],
/// [updateNetwork], [deleteNetwork] and [reorderNetworks] change them; read
/// through [networks.value] or subscribe in an effect.
///
/// Each mutation applies optimistically and rolls back when the write fails,
/// and the mutations run one at a time, so two of them cannot interleave. They
/// persist through the [NetworkStore] that the background service reads.
ReadonlySignal<Map<String, Network>> get networks => _networks;

NetworkStore? _store;

/// Runs every network mutation one at a time.
final _mutations = MutationQueue();

/// Loads the persisted networks out of [store].
///
/// Call once at app startup, before any network operation.
Future<void> init(NetworkStore store) async {
  await dispose();
  _store = store;
  _networks.value = Map.unmodifiable(await store.load());
}

Future<void> _save(Map<String, Network> networks) => _store!.save(networks);

/// Reserved names, including pending renames, excluding [exceptId].
Iterable<String> networkNames({String? exceptId}) => {
  for (final entry in _networks.peek().entries)
    if (entry.key != exceptId) ...[
      entry.value.networkName,
      latestNetwork(entry.key)!.networkName,
    ],
}.toList();

/// Adds the network as [key].
///
/// Throws [StateError] when [key] is already taken.
Future<void> addNetwork(String key, Network network) =>
    _mutations.enqueue(() async {
      final saved = _networks.peek();
      if (saved.containsKey(key)) {
        throw StateError('Network already exists: $key');
      }
      await persistOptimistically(
        _networks,
        Map<String, Network>.unmodifiable(Map.of(saved)..[key] = network),
        _save,
      );
    });

/// Replaces the network saved as [key].
///
/// Throws [StateError] when no network has that key.
Future<void> updateNetwork(String key, Network network) =>
    _mutations.enqueue(() async {
      final saved = _networks.peek();
      if (!saved.containsKey(key)) {
        throw StateError('Network does not exist: $key');
      }
      await persistOptimistically(
        _networks,
        Map<String, Network>.unmodifiable(Map.of(saved)..[key] = network),
        _save,
      );
    });

/// Removes the network saved as [key], and any deferred edit to it.
///
/// Succeeds silently when no network has that key.
Future<void> deleteNetwork(String key) => _mutations.enqueue(() async {
  _discardNetworkEdit(key);
  final saved = _networks.peek();
  if (!saved.containsKey(key)) return;
  await persistOptimistically(
    _networks,
    Map<String, Network>.unmodifiable(Map.of(saved)..remove(key)),
    _save,
  );
});

/// Moves the network at [oldIndex] to [newIndex], which is where it ends up
/// after the move rather than the index it lands in front of.
///
/// Succeeds silently when either index is out of bounds, or when the move
/// leaves the order unchanged.
Future<void> reorderNetworks(int oldIndex, int newIndex) =>
    _mutations.enqueue(() async {
      final saved = _networks.peek();
      final keys = saved.keys.toList();

      if (oldIndex < 0 ||
          oldIndex >= keys.length ||
          newIndex < 0 ||
          newIndex > keys.length) {
        return;
      }

      if (newIndex > oldIndex) newIndex--;
      if (oldIndex == newIndex) return;

      keys.insert(newIndex, keys.removeAt(oldIndex));

      await persistOptimistically(
        _networks,
        Map<String, Network>.unmodifiable({
          for (final key in keys) key: saved[key]!,
        }),
        _save,
      );
    });

/// Flushes deferred editor saves and waits for every queued mutation.
Future<void> settled() async {
  await flushNetworkEdits();
  await _mutations.settled();
}

/// Drops the store and every deferred edit, once the queued mutations finish.
Future<void> dispose() async {
  await settled();
  for (final id in _pendingNetworkEdits.keys.toList()) {
    _discardNetworkEdit(id);
  }
  _store = null;
}

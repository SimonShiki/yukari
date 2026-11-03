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

/// Global network collection state.
///
/// This signal holds all saved networks in the application as an unmodifiable map.
///
/// **Initialization**: Call [init] once at app startup to load persisted networks.
///
/// **Mutation**: Use the provided mutation APIs:
/// - [addNetwork] - Add a new network
/// - [updateNetwork] - Modify an existing network
/// - [deleteNetwork] - Remove a network
/// - [reorderNetworks] - Change display order
///
/// **Read**: Access via [networks.value] or subscribe in effects/computed signals.
///
/// All mutations use optimistic updates with automatic rollback on error.
/// Operations are queued and executed sequentially to prevent race conditions.
/// They persist to the [NetworkStore], which the background service reads.
ReadonlySignal<Map<String, Network>> get networks => _networks;

NetworkStore? _store;

/// Operation queue to ensure sequential execution of all network mutations.
final _mutations = MutationQueue();

/// Initialize the networks signal by loading persisted data from [store].
///
/// Must be called once at app startup before any network operations.
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

/// Add a new network to the collection.
///
/// Throws [StateError] if a network with [key] already exists.
/// Updates are optimistic with automatic rollback on database error.
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

/// Update an existing network in the collection.
///
/// Throws [StateError] if network with [key] does not exist.
/// Updates are optimistic with automatic rollback on database error.
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

/// Delete a network from the collection.
///
/// Silently succeeds if network with [key] does not exist.
/// Updates are optimistic with automatic rollback on database error.
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

/// Reorder networks by moving from [oldIndex] to [newIndex].
///
/// Silently succeeds if indices are out of bounds or equal.
/// Updates are optimistic with automatic rollback on database error.
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

/// Clean up resources when networks signal is no longer needed.
///
/// Waits for all pending operations to complete before disposing.
Future<void> dispose() async {
  await settled();
  for (final id in _pendingNetworkEdits.keys.toList()) {
    _discardNetworkEdit(id);
  }
  _store = null;
}

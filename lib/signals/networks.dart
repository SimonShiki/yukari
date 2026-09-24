import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../models/network.dart';

/// Private backing signal for the global network collection.
/// Use [networks] for readonly access.
final Signal<Map<String, Network>> _networks = signal(const <String, Network>{});

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
ReadonlySignal<Map<String, Network>> get networks => _networks;

SharedPreferences? _prefs;

/// Operation queue to ensure sequential execution of all network mutations.
Future<void> _operations = Future.value();

const _networksKey = 'networks';

/// Initialize the networks signal by loading persisted data.
///
/// Must be called once at app startup before any network operations.
Future<void> init() async {
  await _operations;
  _prefs = await SharedPreferences.getInstance();
  _networks.value = Map.unmodifiable(await _load());
}

Future<Map<String, Network>> _load() async {
  final data = _prefs!.getString(_networksKey);
  if (data == null) return {};

  final json = jsonDecode(data) as Map<String, dynamic>;
  return {
    for (final entry in json.entries)
      entry.key: Network.fromJson(entry.value as Map<String, dynamic>),
  };
}

Future<void> _save(Map<String, Network> networks) async {
  final json = {for (final entry in networks.entries) entry.key: entry.value.toJson()};
  await _prefs!.setString(_networksKey, jsonEncode(json));
}

Future<void> _enqueue(Future<void> Function() operation) {
  final result = _operations.then((_) => operation());
  _operations = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  return result;
}

Future<void> _optimistic(
  Map<String, Network> Function() optimisticUpdate,
  Future<void> Function() persistOperation,
) async {
  final snapshot = _networks.peek();
  _networks.value = Map.unmodifiable(optimisticUpdate());
  try {
    await persistOperation();
  } catch (e) {
    _networks.value = Map.unmodifiable(snapshot);
    rethrow;
  }
}

/// Add a new network to the collection.
///
/// Throws [StateError] if a network with [key] already exists.
/// Updates are optimistic with automatic rollback on database error.
Future<void> addNetwork(String key, Network network) => _enqueue(() async {
  final saved = _networks.peek();
  if (saved.containsKey(key)) {
    throw StateError('Network already exists: $key');
  }
  await _optimistic(
    () => Map.of(saved)..[key] = network,
    () async => await _save(Map.of(saved)..[key] = network),
  );
});

/// Update an existing network in the collection.
///
/// Throws [StateError] if network with [key] does not exist.
/// Updates are optimistic with automatic rollback on database error.
Future<void> updateNetwork(String key, Network network) => _enqueue(() async {
  final saved = _networks.peek();
  if (!saved.containsKey(key)) {
    throw StateError('Network does not exist: $key');
  }
  await _optimistic(
    () => Map.of(saved)..[key] = network,
    () async => await _save(Map.of(saved)..[key] = network),
  );
});

/// Delete a network from the collection.
///
/// Silently succeeds if network with [key] does not exist.
/// Updates are optimistic with automatic rollback on database error.
Future<void> deleteNetwork(String key) => _enqueue(() async {
  final saved = _networks.peek();
  if (!saved.containsKey(key)) return;
  await _optimistic(
    () => Map.of(saved)..remove(key),
    () async => await _save(Map.of(saved)..remove(key)),
  );
});

/// Reorder networks by moving from [oldIndex] to [newIndex].
///
/// Silently succeeds if indices are out of bounds or equal.
/// Updates are optimistic with automatic rollback on database error.
Future<void> reorderNetworks(int oldIndex, int newIndex) => _enqueue(() async {
  final saved = _networks.peek();
  final keys = saved.keys.toList();

  if (oldIndex < 0 || oldIndex >= keys.length || newIndex < 0 || newIndex > keys.length) {
    return;
  }

  if (newIndex > oldIndex) newIndex--;
  if (oldIndex == newIndex) return;

  keys.insert(newIndex, keys.removeAt(oldIndex));

  await _optimistic(
    () => {for (final key in keys) key: saved[key]!},
    () async => await _save({for (final key in keys) key: saved[key]!}),
  );
});

/// Clean up resources when networks signal is no longer needed.
///
/// Waits for all pending operations to complete before disposing.
Future<void> dispose() async {
  await _operations;
  _prefs = null;
}

import 'dart:io';

import 'package:signals/signals.dart';

import '../models/network.dart';
import '../utils/json_store.dart';

String networkDir = '';

final _networks = mapSignal<String, Network>({});

/// The ordered network name list
final _index = listSignal<String>([]);

void Function()? indexCleanup;
// Cleanup functions to remove effects.
Map<String, void Function()> networkCleanups = {};

JsonFileStore<List<String>>? indexStore;
Map<String, JsonFileStore<Network>> networkStores = {};

// --- Lifecycle ---

/// Initializes the network collection from folder [networkDir].
/// This must be called before any other code accesses [networks] and [index].
/// Returns true if the saved data is corrupted and we write back a cleaned-up version to disk
Future<bool> init(String dir) async {
  networkDir = dir;

  /// Whether we should save back the datas to avoid corrupted state in disk.
  bool corrupted = false;
  indexStore = JsonFileStore<List<String>>(
    file: File('$networkDir/index.json'),
    decode: (json) => (json as List).cast<String>(),
    encode: (value) => value,
  );
  if (!await indexStore!.exists()) {
    await indexStore!.save([]);
  }
  try {
    _index.set(await indexStore!.load());
  } catch (e) {
    corrupted = true;
    await indexStore!.save([]);
    _index.set([]);
  }

  final deduped = _index.peek().toSet().toList();
  if (deduped.length != _index.peek().length) {
    corrupted = true;
    _index.set(deduped);
  }

  for (final name in _index.peek().toList()) {
    final store = createNetworkStore(name);
    if (!await store.exists()) {
      corrupted = true;
      _index.remove(name);
      continue;
    }
    networkStores[name] = store;
    try {
      _networks[name] = await store.load();
    } catch (e) {
      // Irrecoverable since it may truly be corrupted and not a good idea to overwrite it.
      // Just throw and let the user know to fix it manually.
      throw StorageException('Failed to load network $name', e);
    }
  }

  // Add effects to save the index and networks when they change.
  indexCleanup = effect(() => indexStore!.save(_index.value));
  for (final name in _index.peek()) {
    final store = networkStores[name]!;
    final s = computed(() => _networks[name]);
    networkCleanups[name] = effect(() => store.save(s.value!));
  }

  return corrupted;
}

JsonFileStore<Network> createNetworkStore(String name) => JsonFileStore<Network>(
  file: File('$networkDir/$name.json'),
  decode: (json) => Network.fromJson(json as Map<String, dynamic>),
  encode: (value) => value.toJson(),
);

Future<void> dispose() async {
  indexCleanup?.call();
  indexCleanup = null;
  for (final cleanup in networkCleanups.values) {
    cleanup();
  }
  networkCleanups.clear();
  networkStores.clear();
  batch(() {
    _index.clear();
    _networks.clear();
  });
}

// --- Accessors ---

final ReadonlySignal<List<String>> index = _index;
final ReadonlySignal<Map<String, Network>> networks = _networks;

/// Adds a new network to the collection. Throws if a network with the same name already exists.
void addNetwork(String name, Network network) {
  if (_index.peek().contains(name)) {
    throw StateError('Network $name already exists');
  }
  final store = createNetworkStore(name);
  networkStores[name] = store;
  batch(() {
    _index.add(name);
    _networks[name] = network;
  });
  final s = computed(() => _networks[name]);
  networkCleanups[name] = effect(() => store.save(s.value!));
}

/// Reorder the network index to move the network at [fromIndex] to [newIndex].
void reorderIndex(int fromIndex, int newIndex) {
  if (fromIndex < 0 || fromIndex >= _index.peek().length) {
    throw RangeError.index(fromIndex, _index.peek(), 'fromIndex');
  }
  if (newIndex < 0 || newIndex >= _index.peek().length) {
    throw RangeError.index(newIndex, _index.peek(), 'newIndex');
  }
  final name = _index.peek()[fromIndex];
  batch(() {
    _index.removeAt(fromIndex);
    _index.insert(newIndex, name);
  });
}

/// Update the network with [name] by calling [updater] to modify it in place.
/// Updater can update the network itselfs other than its name.
/// If you want to rename the network, use [renameNetwork] instead.
void updateNetwork(String name, {Network? newNetwork, void Function(Network)? updater}) {
  final network = _networks[name];
  if (network == null) {
    throw StateError('Network $name does not exist');
  }
  if (newNetwork != null) {
    _networks[name] = newNetwork;
  } else if (updater != null) {
    updater(network);
  }

  // Deep-copy the network to trigger the signal update.
  _networks[name] = Network.fromJson(network.toJson());
}

/// Renames the network with [oldName] to [newName]. Throws if a network with [newName] already exists.
void renameNetwork(String oldName, String newName) {
  final position = _index.peek().indexOf(oldName);
  if (position < 0) {
    throw StateError('Network $oldName does not exist');
  }
  if (_index.peek().contains(newName)) {
    throw StateError('Network $newName already exists');
  }

  Network network = _networks[oldName]!;
  network.networkName = newName;
  batch(() {
    removeNetwork(oldName);
    addNetwork(newName, network);
    reorderIndex(_index.peek().length - 1, position);
  });
}

/// Removes a network from the collection.
void removeNetwork(String name) {
  networkCleanups[name]?.call();
  networkCleanups.remove(name);
  batch(() {
    _index.remove(name);
    _networks.remove(name);
  });
  networkStores[name]?.clear();
  networkStores.remove(name);
}

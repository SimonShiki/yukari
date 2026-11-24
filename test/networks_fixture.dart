import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/signals/instances.dart' as running;
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari_core/storage/network_store.dart';

late NetworkStore _store;

/// A store in a fresh temporary directory, deleted after the test.
NetworkStore temporaryStore() {
  final directory = Directory.systemTemp.createTempSync('yukari_test_');
  addTearDown(() => directory.delete(recursive: true));
  return NetworkStore.inDirectory(directory.path);
}

/// Seeds the saved networks signal with [networks] from a fresh store, which
/// becomes the one [persisted] reads.
///
/// It also empties the running-instances store, which is module state the
/// controller tests share: without that, a collection one test left behind
/// would decide what the next one sees.
Future<NetworkStore> seedWith(Map<String, Network> networks) async {
  final store = _store = temporaryStore();
  await store.save(networks);
  await saved.init(store);
  running.initInstances();
  addTearDown(saved.dispose);
  return store;
}

/// Seeds the saved networks `n1` ("alpha") and `n2` ("beta").
Future<void> seedNetworks() => seedWith({
  'n1': Network()..networkName = 'alpha',
  'n2': Network()..networkName = 'beta',
});

/// A saved network named [name] with one peer, so it can be shared.
Network shareableNetwork(String name) => Network()
  ..networkName = name
  ..nodes = [
    Node(
      url: Uri(scheme: 'tcp', host: 'relay.example.com', port: 11010),
      name: 'peer',
    ),
  ];

/// Seeds `n1`/`n2` into a store whose writes fail from now on.
Future<void> seedWithFailingWrites() async {
  final store = await seedWith({
    'n1': Network()..networkName = 'alpha',
    'n2': Network()..networkName = 'beta',
  });
  // A directory where the store writes makes every save fail.
  store.file.deleteSync();
  Directory(store.file.path).createSync(recursive: true);
}

/// The network `id` as persisted in the store.
///
/// Reads synchronously, as file futures never complete in fake-async zones.
Future<Network> persisted(String id) async {
  final json = jsonDecode(_store.file.readAsStringSync()) as Map;
  return Network.fromJson(json[id] as Map<String, dynamic>);
}

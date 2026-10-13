import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:yukari/models/network.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/storage/network_store.dart';

late NetworkStore _store;

/// A store in a fresh temporary directory, deleted after the test.
NetworkStore temporaryStore() {
  final directory = Directory.systemTemp.createTempSync('yukari_test_');
  addTearDown(() => directory.delete(recursive: true));
  return NetworkStore.inDirectory(directory.path);
}

/// Seeds the saved networks `n1` ("alpha") and `n2` ("beta").
Future<void> seedNetworks() async {
  _store = temporaryStore();
  await _store.save({
    'n1': Network()..networkName = 'alpha',
    'n2': Network()..networkName = 'beta',
  });
  await saved.init(_store);
  addTearDown(saved.dispose);
}

/// The network `id` as persisted in the store.
///
/// Reads synchronously, as file futures never complete in fake-async zones.
Future<Network> persisted(String id) async {
  final json = jsonDecode(_store.file.readAsStringSync()) as Map;
  return Network.fromJson(json[id] as Map<String, dynamic>);
}

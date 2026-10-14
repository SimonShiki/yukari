import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/network.dart';
import 'json_file.dart';

/// Saved networks in one JSON file, shared by the app and the service.
///
/// The app is the only writer. The service opens the same file [readOnly]
/// and loads it whenever it needs the current networks. Writes replace the
/// file atomically, so a reader never sees a half-written file.
final class NetworkStore {
  NetworkStore(this.file, {this.readOnly = false});

  /// The store kept in the data directory [dataDir].
  factory NetworkStore.inDirectory(String dataDir, {bool readOnly = false}) =>
      NetworkStore(File(p.join(dataDir, 'networks.json')), readOnly: readOnly);

  final File file;
  final bool readOnly;

  /// Saved networks in display order; empty when nothing was saved yet.
  Future<Map<String, Network>> load() async {
    if (!await file.exists()) return {};
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: Network.fromJson(value as Map<String, dynamic>),
    };
  }

  /// Replaces the saved networks with [networks], keeping their order.
  Future<void> save(Map<String, Network> networks) async {
    if (readOnly) throw StateError('The network store is read-only');
    await replaceWithJson(file, networks);
  }
}

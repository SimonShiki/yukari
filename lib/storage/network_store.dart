import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/network.dart';

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
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(networks),
      flush: true,
    );
    // Windows refuses to replace a file someone is reading, such as the
    // service loading it; reads are short, so try again shortly.
    for (var attempt = 1; ; attempt++) {
      try {
        await temporary.rename(file.path);
        return;
      } on FileSystemException {
        if (!Platform.isWindows || attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
  }
}

import 'package:uuid/uuid.dart';

import '../signals/bookmarks.dart' as saved;
import '../signals/networks.dart' as networks;
import 'share_document.dart';
import 'share_masking.dart';

/// Saves [document] as a new network under a fresh id.
///
/// Returns the name the network was saved under, which is numbered when a
/// saved network already uses the shared name.
Future<String> addSharedNetwork(ShareDocument document) async {
  final id = const Uuid().v4();
  final network = networkFromShare(
    document,
    takenNames: networks.networkNames(),
  );
  await networks.addNetwork(id, network);
  return network.networkName;
}

/// Saves the node [document] shares as a bookmark under a fresh id.
///
/// Returns the saved connection URL, or null when that connection is
/// already saved.
Future<String?> addSharedNode(ShareDocument document) async {
  String? firstAddress;
  for (final peer in document.peers) {
    final bookmark = bookmarkFromShare(
      ShareDocument(kind: ShareKind.node, name: document.name, peers: [peer]),
      id: const Uuid().v4(),
    );
    if (saved.bookmarkFor(bookmark.node) != null) continue;
    await saved.addBookmark(bookmark);
    firstAddress ??= bookmark.address;
  }
  return firstAddress;
}

/// What a batch import did: added, already saved, and failed, per document.
typedef ShareImportSummary = ({int added, int duplicates, int failed});

/// Saves every document in [documents], in order, and reports what happened.
///
/// A failure is per item: the rest still save, and the caller reports the whole
/// batch instead of the first error. A network always adds, under a numbered
/// name when one is taken; a node whose address is already bookmarked counts as
/// a duplicate instead.
Future<ShareImportSummary> addSharedDocuments(
  List<ShareDocument> documents, {
  ShareImporter importer = ShareImporter.defaults,
}) async {
  var added = 0;
  var duplicates = 0;
  var failed = 0;
  for (final document in documents) {
    try {
      final saved = switch (document.kind) {
        ShareKind.network => await importer.addNetwork(document),
        ShareKind.node => await importer.addNode(document),
      };
      // Only a node reports a duplicate, by returning no address.
      if (saved == null) {
        duplicates++;
      } else {
        added++;
      }
    } on Object {
      failed++;
    }
  }
  return (added: added, duplicates: duplicates, failed: failed);
}

/// Saves a decoded share; injected where the app's stores must stay untouched,
/// as in tests.
final class ShareImporter {
  /// Creates an importer over the two save functions.
  const ShareImporter({required this.addNetwork, required this.addNode});

  /// The real importer: [addSharedNetwork] and [addSharedNode].
  static const defaults = ShareImporter(
    addNetwork: addSharedNetwork,
    addNode: addSharedNode,
  );

  /// Saves the network [document] describes, returning the name it got.
  final Future<String> Function(ShareDocument document) addNetwork;

  /// Saves the node [document] describes, returning its address, or null when a
  /// bookmark for that address already exists.
  final Future<String?> Function(ShareDocument document) addNode;
}

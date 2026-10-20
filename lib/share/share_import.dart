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
/// Returns the saved `host:port`, or null when a bookmark for that address is
/// already saved.
Future<String?> addSharedNode(ShareDocument document) async {
  final bookmark = bookmarkFromShare(document, id: const Uuid().v4());
  if (saved.bookmarkFor(bookmark.node) != null) return null;
  await saved.addBookmark(bookmark);
  return bookmark.address;
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

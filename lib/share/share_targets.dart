import '../constants/builtin_bookmarks.dart';
import '../signals/bookmarks.dart' as saved;
import '../signals/networks.dart' as networks;
import 'share_document.dart';
import 'share_masking.dart';

/// Why there is no shareable document for a target.
enum ShareUnavailableReason {
  networkMissing,
  bookmarkMissing,
  networkWithoutPeers,
  unsupported,
}

/// The document to share, or why there is none.
typedef ShareTarget = ({
  ShareDocument? document,
  ShareUnavailableReason? reason,
});

/// The share target stored under [id]: the document to share, or why the
/// sender has nothing to share.
///
/// A document is only returned when it survives [ShareDocument.decode], so the
/// sender never streams something the receiver's own validator refuses.
ShareTarget resolveShareTarget(ShareKind kind, String id) => switch (kind) {
  ShareKind.network => _networkTarget(id),
  ShareKind.node => _bookmarkTarget(id),
};

ShareTarget _networkTarget(String id) {
  final network = networks.networks.peek()[id];
  if (network == null) {
    return (document: null, reason: ShareUnavailableReason.networkMissing);
  }
  if (network.nodes.isEmpty) {
    return (document: null, reason: ShareUnavailableReason.networkWithoutPeers);
  }
  return _validated(() => shareNetwork(network));
}

ShareTarget _bookmarkTarget(String id) {
  final bookmark = [
    ...builtinBookmarks,
    ...saved.bookmarks.peek(),
  ].where((bookmark) => bookmark.id == id).firstOrNull;
  if (bookmark == null) {
    return (document: null, reason: ShareUnavailableReason.bookmarkMissing);
  }
  return _validated(() => shareBookmark(bookmark));
}

/// The document [build] makes when it round-trips through the receiver's own
/// validator, else [ShareUnavailableReason.unsupported].
///
/// Failures never escape: a target the sender cannot mask or the receiver
/// would refuse is reported as unsupported instead of crashing the page.
ShareTarget _validated(ShareDocument Function() build) {
  try {
    final document = build();
    ShareDocument.decode(document.encode());
    return (document: document, reason: null);
  } on StateError {
    return (document: null, reason: ShareUnavailableReason.unsupported);
  } on FormatException {
    return (document: null, reason: ShareUnavailableReason.unsupported);
  }
}

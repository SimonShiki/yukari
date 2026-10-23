import 'package:yukari_core/models/bookmark.dart';

import '../constants/builtin_bookmarks.dart';
import '../signals/bookmarks.dart' as saved;
import '../signals/networks.dart' as networks;
import 'share_bundle.dart';
import 'share_configs.dart';
import 'share_document.dart';
import 'share_masking.dart';
import 'share_options.dart';
import 'share_self_peer.dart';

/// Why there is no shareable document for a target.
enum ShareUnavailableReason {
  networkMissing,
  bookmarkMissing,
  networkWithoutPeers,
  unsupported,
}

/// The documents to share, the extras they can still offer, or why the sender
/// has nothing to share.
typedef ShareTarget = ({
  List<ShareDocument> documents,
  ShareUnavailableReason? reason,
  ShareExtras extras,
});

/// Re-resolves a target for the options the sender picked, so a toggle rebuilds
/// the document without the page knowing how it was masked.
typedef ShareResolver = ShareTarget Function(ShareOptions options);

/// The documents stored under [ids] with [options] applied, or why the sender
/// has nothing to share.
///
/// All-or-nothing: one id that no longer resolves and the page says why instead
/// of sharing the rest, so a bundle never silently loses an item.
ShareTarget resolveShareItems(
  ShareKind kind,
  List<String> ids, {
  ShareOptions options = noShareOptions,
}) {
  if (ids.isEmpty) return _unavailable(_missingFor(kind));

  final missing = _missingReason(kind, ids);
  if (missing != null) return _unavailable(missing);
  return _validated(
    () => [for (final id in ids) _documentFor(kind, id, options)],
    _extrasFor(kind, ids),
  );
}

/// The share target stored under [id]: the document to share, or why the
/// sender has nothing to share.
ShareTarget resolveShareTarget(
  ShareKind kind,
  String id, {
  ShareOptions options = noShareOptions,
}) => resolveShareItems(kind, [id], options: options);

/// Why a link with no id at all says its target is missing.
ShareUnavailableReason _missingFor(ShareKind kind) => switch (kind) {
  ShareKind.network => ShareUnavailableReason.networkMissing,
  ShareKind.node => ShareUnavailableReason.bookmarkMissing,
};

ShareTarget _unavailable(ShareUnavailableReason reason) =>
    (documents: const <ShareDocument>[], reason: reason, extras: noShareExtras);

/// Why one of [ids] has nothing to share, or null when every id resolves.
ShareUnavailableReason? _missingReason(ShareKind kind, List<String> ids) {
  for (final id in ids) {
    final reason = switch (kind) {
      ShareKind.network => _networkReason(id),
      ShareKind.node =>
          _bookmarkNamed(id) == null
              ? ShareUnavailableReason.bookmarkMissing
              : null,
    };
    if (reason != null) return reason;
  }
  return null;
}

ShareUnavailableReason? _networkReason(String id) {
  final network = networks.networks.peek()[id];
  if (network == null) return ShareUnavailableReason.networkMissing;
  if (network.nodes.isEmpty) {
    return ShareUnavailableReason.networkWithoutPeers;
  }
  return null;
}

/// The extras [ids] can still add: a node share offers none, and a bundle
/// offers an option when any of its networks can honour it.
ShareExtras _extrasFor(ShareKind kind, List<String> ids) {
  if (kind != ShareKind.network) return noShareExtras;
  var selfPeer = false;
  var configs = false;
  for (final id in ids) {
    final network = networks.networks.peek()[id];
    if (network == null) continue;
    selfPeer = selfPeer || selfPeerForShare(network) != null;
    configs = configs || configsOf(network) != null;
  }
  return (selfPeer: selfPeer, configs: configs);
}

/// The document [id] shares; [_missingReason] said there is one.
///
/// A store that lost the target in between is a [StateError], which
/// [_validated] reports as unsupported rather than as missing.
ShareDocument _documentFor(ShareKind kind, String id, ShareOptions options) {
  if (kind == ShareKind.network) {
    final network = networks.networks.peek()[id];
    if (network == null) throw StateError('Share target $id is missing');
    return shareNetwork(network, options: options);
  }
  final bookmark = _bookmarkNamed(id);
  if (bookmark == null) throw StateError('Share target $id is missing');
  return shareBookmark(bookmark);
}

Bookmark? _bookmarkNamed(String id) => [
  ...builtinBookmarks,
  ...saved.bookmarks.peek(),
].where((bookmark) => bookmark.id == id).firstOrNull;

/// The documents [build] makes when they round-trip through the receiver's own
/// validator, else [ShareUnavailableReason.unsupported].
///
/// Failures never escape: a target the sender cannot mask or the receiver would
/// refuse is reported as unsupported instead of crashing the page.
ShareTarget _validated(
  List<ShareDocument> Function() build,
  ShareExtras extras,
) {
  try {
    final documents = build();
    final decoded = decodeShareItems(encodeShareItems(documents));
    if (decoded.length != documents.length) {
      return _unavailable(ShareUnavailableReason.unsupported);
    }
    return (documents: documents, reason: null, extras: extras);
  } on StateError {
    return _unavailable(ShareUnavailableReason.unsupported);
  } on FormatException {
    return _unavailable(ShareUnavailableReason.unsupported);
  } on ArgumentError {
    return _unavailable(ShareUnavailableReason.unsupported);
  }
}

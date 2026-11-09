import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

import 'share_configs.dart';
import 'share_document.dart';
import 'share_options.dart';
import 'share_self_peer.dart';

/// The full connection URL and public key, without local annotations.
/// Credentials in a URL require explicit handling and cannot be shared.
SharedPeer sharedPeer(Node node) {
  if (node.url.userInfo.isNotEmpty) {
    throw StateError('Node address carries credentials');
  }
  return SharedPeer(url: node.url, publicKey: node.publicKey);
}

/// The masked share document of [network]: its name, its secret and one peer
/// per node, plus the extras [options] asks for, and nothing else.
///
/// An opted-in self peer uses the same URL entry as any other peer. Throws a
/// [StateError] when the network has no peer, as the receiver would have
/// nothing to connect to, or when a node's address carries credentials.
ShareDocument shareNetwork(
  Network network, {
  ShareOptions options = noShareOptions,
}) {
  if (network.nodes.isEmpty) {
    throw StateError('Cannot share a network without peers');
  }
  final peers = [for (final node in network.nodes) sharedPeer(node)];
  final self = options.includeSelf ? selfPeerForShare(network) : null;
  if (self != null) peers.add(self);
  return ShareDocument(
    kind: ShareKind.network,
    name: network.networkName,
    secret: _trimmedOrNull(network.networkSecret),
    configs: options.includeConfigs ? configsOf(network) : null,
    peers: peers,
  );
}

/// The masked share document of the single node [bookmark] saves.
///
/// The bookmark's name travels as the document's name, so the receiver saves
/// the node under the name the sender gave it. The description, category, tags,
/// extensions and id are local annotations and are not shared. Throws a
/// [StateError] when the node's address carries credentials.
ShareDocument shareBookmark(Bookmark bookmark) => ShareDocument(
  kind: ShareKind.node,
  name: _sharedName(bookmark.name),
  peers: [sharedPeer(bookmark.node)],
);

/// A new local [Network] for [document], with every local setting left at
/// [Network]'s default except the configs the share carried.
///
/// The shared name is kept, or numbered when [takenNames] already holds it,
/// and each connection keeps its full URL as its initial local name.
Network networkFromShare(
  ShareDocument document, {
  required Iterable<String> takenNames,
}) {
  final name = document.name;
  if (document.kind != ShareKind.network || name == null) {
    throw ArgumentError.value(document, 'document', 'Not a network share');
  }
  final network = Network()
    ..networkName = _uniqueName(name, takenNames)
    ..networkSecret = document.secret
    ..nodes = [for (final peer in document.peers) _nodeFromPeer(peer)];
  if (document.configs case final configs?) applyConfigs(network, configs);
  return network;
}

/// A new local [Bookmark] for the single node [document] shares, saved under
/// [id], under the shared name or the peer's host when the share carries none.
Bookmark bookmarkFromShare(ShareDocument document, {required String id}) {
  if (document.kind != ShareKind.node) {
    throw ArgumentError.value(document, 'document', 'Not a node share');
  }
  final peer = document.peers.single;
  return Bookmark(
    id: id,
    node: _nodeFromPeer(peer),
    name: document.name ?? peer.url.host,
  );
}

/// A [Node] that connects to [peer].
Node _nodeFromPeer(SharedPeer peer) =>
    Node(name: peer.address, url: peer.url, publicKey: peer.publicKey);

/// [name], suffixed with the first free ` (2)`, ` (3)`, ... in [takenNames].
String _uniqueName(String name, Iterable<String> takenNames) {
  final taken = takenNames.toSet();
  if (!taken.contains(name)) return name;
  var suffix = 2;
  while (taken.contains('$name ($suffix)')) {
    suffix++;
  }
  return '$name ($suffix)';
}

/// [value] trimmed, or null when it is null or blank.
String? _trimmedOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

/// [name] as a share document carries it: trimmed, null when blank, and clamped
/// to [shareMaxNameLength] without splitting a surrogate pair.
String? _sharedName(String? name) {
  final text = _trimmedOrNull(name);
  if (text == null || text.length <= shareMaxNameLength) return text;
  final last = text.codeUnitAt(shareMaxNameLength - 1);
  final end = last >= 0xD800 && last <= 0xDBFF
      ? shareMaxNameLength - 1
      : shareMaxNameLength;
  return text.substring(0, end).trimRight();
}

import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

import 'share_document.dart';

/// The shareable peer [node] describes.
///
/// Only the host, port and an authority-relative path travel; the node's saved
/// id and the network's listeners stay local. EasyTier addresses a peer by
/// scheme, host, port and path and authenticates with the network secret, so a
/// URL's user info (a credential) is never shared, and a node that needs it
/// cannot be shared as it is. A bare-host URI stores the host in `url.path`, so
/// only a URL that has an authority shares its path. [Node.publicKey] is shared
/// when set, as a public key lets the receiver pin the peer the sender
/// recommended.
///
/// Throws a [StateError] when the address carries credentials.
SharedPeer sharedPeer(Node node) {
  if (node.url.userInfo.isNotEmpty) {
    throw StateError('Node address carries credentials');
  }
  return SharedPeer(
    host: nodeHost(node.url),
    port: node.port,
    protocols: node.protocols.toSet().toList(),
    publicKey: node.publicKey,
    path: node.url.host.isNotEmpty && node.url.path.isNotEmpty
        ? node.url.path
        : null,
  );
}

/// The masked share document of [network]: its name, its secret and one peer
/// per node, and nothing else.
///
/// Throws a [StateError] when the network has no peer, as the receiver would
/// have nothing to connect to, or when a node's address carries credentials.
ShareDocument shareNetwork(Network network) {
  if (network.nodes.isEmpty) {
    throw StateError('Cannot share a network without peers');
  }
  return ShareDocument(
    kind: ShareKind.network,
    name: network.networkName,
    secret: _trimmedOrNull(network.networkSecret),
    peers: [for (final node in network.nodes) sharedPeer(node)],
  );
}

/// The masked share document of the single node [bookmark] saves.
///
/// The bookmark's name, description, category, tags and extensions are local
/// annotations and are not shared. Throws a [StateError] when the node's
/// address carries credentials.
ShareDocument shareBookmark(Bookmark bookmark) =>
    ShareDocument(kind: ShareKind.node, peers: [sharedPeer(bookmark.node)]);

/// A new local [Network] for [document], with every local setting left at
/// [Network]'s default.
///
/// The shared name is kept, or numbered when [takenNames] already holds it,
/// and the imported nodes take [SharedPeer.address] as their id so they never
/// collide with a node saved here before.
Network networkFromShare(
  ShareDocument document, {
  required Iterable<String> takenNames,
}) {
  final name = document.name;
  if (document.kind != ShareKind.network || name == null) {
    throw ArgumentError.value(document, 'document', 'Not a network share');
  }
  return Network()
    ..networkName = _uniqueName(name, takenNames)
    ..networkSecret = document.secret
    ..nodes = [for (final peer in document.peers) _nodeFromPeer(peer)];
}

/// A new local [Bookmark] for the single node [document] shares, saved under
/// [id].
Bookmark bookmarkFromShare(ShareDocument document, {required String id}) {
  if (document.kind != ShareKind.node) {
    throw ArgumentError.value(document, 'document', 'Not a node share');
  }
  final peer = document.peers.single;
  return Bookmark(id: id, node: _nodeFromPeer(peer), name: peer.host);
}

/// A [Node] that connects to [peer].
Node _nodeFromPeer(SharedPeer peer) => Node(
  id: peer.address,
  url: peer.path == null
      ? nodeUrlForHost(peer.host)
      : Uri(host: peer.host, path: peer.path),
  port: peer.port,
  protocols: peer.protocols,
  publicKey: peer.publicKey,
);

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

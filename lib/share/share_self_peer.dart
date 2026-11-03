import 'dart:convert';

import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

import 'share_document.dart';

/// Hosts that name the sender's own machine instead of an address another
/// device can dial: a wildcard bind, a loopback name, or no host at all.
const Set<String> _undialableHosts = {
  '',
  '0.0.0.0',
  '::',
  '0:0:0:0:0:0:0:0',
  '127.0.0.1',
  '::1',
  'localhost',
};

/// The peer a share of [network] adds for this device, or null when it cannot
/// add one: the network publishes no address another device could dial, one of
/// its saved peers already sits at that address, or the share has no room left
/// under [shareMaxPeers].
///
/// The sender's availability and the peer the masker writes come from this one
/// answer, so the switch a user sees and the peers a share carries cannot
/// disagree.
SharedPeer? selfPeerForShare(Network network) {
  final self = selfPeerOf(network);
  if (self == null) return null;
  if (network.nodes.length + 1 > shareMaxPeers) return null;
  return network.nodes.any((node) => nodeHostPort(node) == self.address)
      ? null
      : self;
}

/// A peer entry that offers this device to whoever receives the share, or null
/// when the network publishes no address another device could dial.
///
/// A mapped listener is what the network advertises to peers outside the local
/// one, so it is tried first; a later listener with the same address only adds
/// the protocols it offers, and the first path one names. The peer carries
/// [Network.secureMode]'s public key when that mode is on and the key is one a
/// peer can authenticate with, so the receiver can pin this device; without a
/// usable key the peer is still offered, as the receiver can join with the
/// network secret alone.
SharedPeer? selfPeerOf(Network network) {
  (String, int)? address;
  final protocols = <NodeProtocol>[];
  String? path;
  for (final listener in [...network.mappedListeners, ...network.listeners]) {
    final peer = _listenerPeer(listener);
    if (peer == null) continue;
    final (host, port, protocol, listenerPath) = peer;
    if (address == null) {
      address = (host, port);
    } else if (address != (host, port)) {
      continue;
    }
    if (!protocols.contains(protocol)) protocols.add(protocol);
    path ??= listenerPath;
  }
  final found = address;
  if (found == null) return null;
  return SharedPeer(
    host: found.$1,
    port: found.$2,
    protocols: protocols,
    publicKey: _publicKeyOf(network),
    path: path,
  );
}

/// The address and protocol [listener] publishes, or null when it is not
/// dialable.
(String, int, NodeProtocol, String?)? _listenerPeer(Uri listener) {
  // A listener's user info is a credential, and a share never carries one.
  if (listener.userInfo.isNotEmpty) return null;
  final protocol = NodeProtocol.values.asNameMap()[listener.scheme];
  if (protocol == null) return null;
  final host = nodeHost(listener);
  if (_undialable(host) || !shareableHost(host)) return null;
  final port = listener.port;
  if (port < 1 || port > 65535) return null;
  final path = listener.host.isNotEmpty && listener.path.isNotEmpty
      ? listener.path
      : null;
  return (host, port, protocol, path);
}

/// Whether [host] names this machine rather than an address another device can
/// reach: a wildcard bind, a loopback address in any written form, or the
/// loopback name.
bool _undialable(String host) {
  final lower = host.toLowerCase();
  return _undialableHosts.contains(lower) ||
      lower.startsWith('127.') ||
      lower.startsWith('::ffff:127.');
}

/// The public key a receiver can pin this device with, or null when secure
/// mode is off or the key is not the 32-byte one that mode uses.
String? _publicKeyOf(Network network) {
  final secureMode = network.secureMode;
  if (secureMode == null || !secureMode.enabled) return null;
  final key = secureMode.localPublicKey?.trim();
  if (key == null || key.isEmpty) return null;
  try {
    return base64.decode(key).length == 32 ? key : null;
  } on FormatException {
    return null;
  }
}

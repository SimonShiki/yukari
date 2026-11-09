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
  return network.nodes.any((node) => node.url == self.url) ? null : self;
}

/// A peer entry that offers this device to whoever receives the share, or null
/// when the network publishes no address another device could dial.
///
/// A mapped listener is what the network advertises to peers outside the local
/// one, so its first dialable connection URL is tried first. The peer carries
/// [Network.secureMode]'s public key when that mode is on and the key is one a
/// peer can authenticate with, so the receiver can pin this device; without a
/// usable key the peer is still offered, as the receiver can join with the
/// network secret alone.
SharedPeer? selfPeerOf(Network network) {
  for (final listener in [...network.mappedListeners, ...network.listeners]) {
    if (listener.userInfo.isNotEmpty ||
        !isValidNodeUrl(listener.toString()) ||
        _undialable(listener.host) ||
        !shareableHost(listener.host)) {
      continue;
    }
    return SharedPeer(url: listener, publicKey: _publicKeyOf(network));
  }
  return null;
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

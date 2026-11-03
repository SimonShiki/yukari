import 'dart:math';

import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_masking.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

/// A shared network with a secret, two peers, their protocols and one key.
ShareDocument sharedNetworkDocument() => const ShareDocument(
  kind: ShareKind.network,
  name: 'alpha',
  secret: 's3cret',
  peers: [
    SharedPeer(
      host: 'relay.example.com',
      port: 11010,
      protocols: [NodeProtocol.tcp, NodeProtocol.udp],
      publicKey: 'public-key',
    ),
    SharedPeer(host: '::1', port: 443, protocols: [NodeProtocol.wss]),
  ],
);

/// A shared node for `relay.example.com:11010`, with its public key and, when
/// [name] is given, the bookmark name that travels with it.
ShareDocument sharedNodeDocument({String? name}) => ShareDocument(
  kind: ShareKind.node,
  name: name,
  peers: const [
    SharedPeer(
      host: 'relay.example.com',
      port: 11010,
      protocols: [NodeProtocol.quic],
      publicKey: 'public-key',
    ),
  ],
);

/// A shared network called [name] with one peer, so a bundle of them keeps a
/// readable order.
ShareDocument networkShare(String name) => ShareDocument(
  kind: ShareKind.network,
  name: name,
  peers: const [
    SharedPeer(
      host: 'relay.example.com',
      port: 11010,
      protocols: [NodeProtocol.tcp],
    ),
  ],
);

String _noise(int seed, int length) {
  final random = Random(seed);
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes([
    for (var index = 0; index < length; index++)
      alphabet.codeUnitAt(random.nextInt(alphabet.length)),
  ]);
}

/// The saved network whose share is [noiseNetworkShare]: the same [peers]
/// pseudo-random peers, so a page resolving it streams rather than fitting one
/// code.
Network noiseNetwork({required int peers}) => Network()
  ..networkName = 'alpha'
  ..networkSecret = _noise(1, 120)
  ..nodes = [
    for (var index = 0; index < peers; index++)
      Node(
        id: 'relay-${_noise(10 + index, 10)}.example.net:${10000 + index}',
        url: Uri.parse('relay-${_noise(10 + index, 10)}.example.net'),
        port: 10000 + index,
        protocols: const [NodeProtocol.tcp, NodeProtocol.quic],
        publicKey: _noise(100 + index, 40),
      ),
  ];

/// A network share with [peers] pseudo-random peers, so the document does not
/// compress below its size and the density presets have room to differ.
///
/// Twelve peers compress to 855 bytes, more than the borderline preset's one
/// code carries, so this is the smallest fixture that still streams.
ShareDocument noiseNetworkShare({required int peers}) =>
    shareNetwork(noiseNetwork(peers: peers));

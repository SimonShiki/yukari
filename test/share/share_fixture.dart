import 'dart:math';

import 'package:yukari_core/models/node.dart';
import 'package:yukari/share/share_document.dart';

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

/// A shared node for `relay.example.com:11010`, with its public key.
ShareDocument sharedNodeDocument() => const ShareDocument(
  kind: ShareKind.node,
  peers: [
    SharedPeer(
      host: 'relay.example.com',
      port: 11010,
      protocols: [NodeProtocol.quic],
      publicKey: 'public-key',
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

/// A network share with [peers] pseudo-random peers, so the document does not
/// compress below its size and the density presets have room to differ.
ShareDocument noiseNetworkShare({required int peers}) => ShareDocument(
  kind: ShareKind.network,
  name: 'alpha',
  secret: _noise(1, 120),
  peers: [
    for (var index = 0; index < peers; index++)
      SharedPeer(
        host: 'relay-${_noise(10 + index, 10)}.example.net',
        port: 10000 + index,
        protocols: const [NodeProtocol.tcp, NodeProtocol.quic],
        publicKey: _noise(100 + index, 40),
      ),
  ],
);

/// 672 compressed bytes, so Easy, Balanced and Fast need 3, 2 and 1 blocks.
ShareDocument largeShareDocument() => noiseNetworkShare(peers: 8);

/// 2110 compressed bytes: more than one QR code can carry, so Fast still
/// needs two frames.
ShareDocument hugeShareDocument() => noiseNetworkShare(peers: 40);

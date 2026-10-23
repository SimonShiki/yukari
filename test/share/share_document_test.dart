import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/share/share_document.dart';

import 'share_fixture.dart';

void main() {
  test('round-trips a network document', () {
    final decoded = ShareDocument.decode(sharedNetworkDocument().encode());

    expect(decoded.kind, ShareKind.network);
    expect(decoded.name, 'alpha');
    expect(decoded.secret, 's3cret');
    expect(decoded.hasSecret, isTrue);
    expect(decoded.peers.map((peer) => peer.address), [
      'relay.example.com:11010',
      '::1:443',
    ]);
    expect(decoded.peers.first.protocols, [NodeProtocol.tcp, NodeProtocol.udp]);
    expect(decoded.peers.first.publicKey, 'public-key');
    expect(decoded.peers.last.publicKey, isNull);
  });

  test('round-trips a node document', () {
    final decoded = ShareDocument.decode(sharedNodeDocument().encode());

    expect(decoded.kind, ShareKind.node);
    expect(decoded.name, isNull);
    expect(decoded.secret, isNull);
    expect(decoded.hasSecret, isFalse);
    expect(decoded.peers.single.address, 'relay.example.com:11010');
    expect(decoded.peers.single.protocols, [NodeProtocol.quic]);
    expect(decoded.peers.single.publicKey, 'public-key');
    expect(decoded.peers.single.path, isNull);
  });

  test('round-trips an authority-relative peer path', () {
    final document = ShareDocument(
      kind: ShareKind.node,
      peers: [
        SharedPeer(
          host: 'relay.example.com',
          port: 443,
          protocols: const [NodeProtocol.wss],
          path: '/ws',
        ),
      ],
    );

    final peersJson =
        (jsonDecode(document.encode()) as Map<String, Object?>)['peers']
            as List<Object?>;
    expect((peersJson.single as Map<String, Object?>)['path'], '/ws');
    expect(ShareDocument.decode(document.encode()).peers.single.path, '/ws');
  });

  test('accepts a percent-encoded path that round-trips', () {
    final decoded = ShareDocument.decode(
      jsonEncode({
        'v': shareDocumentVersion,
        'kind': 'node',
        'peers': [
          {
            'host': 'relay.example.com',
            'port': 443,
            'protocols': ['wss'],
            'path': '/%E4%BD%A0%E5%A5%BD',
          },
        ],
      }),
    );

    expect(decoded.peers.single.path, '/%E4%BD%A0%E5%A5%BD');
  });

  test('encodes the versioned wire format', () {
    final json =
        jsonDecode(sharedNetworkDocument().encode()) as Map<String, Object?>;

    expect(json['v'], shareDocumentVersion);
    expect(json['kind'], 'network');
    expect(json['name'], 'alpha');
    expect(json['secret'], 's3cret');
    expect(json['peers'], [
      {
        'host': 'relay.example.com',
        'port': 11010,
        'protocols': ['tcp', 'udp'],
        'publicKey': 'public-key',
      },
      {
        'host': '::1',
        'port': 443,
        'protocols': ['wss'],
      },
    ]);
  });

  test('decodes a parsed root, so a bundle can reuse the field checks', () {
    final root =
        jsonDecode(sharedNodeDocument().encode()) as Map<String, Object?>;

    final decoded = ShareDocument.decodeRoot(root);

    expect(decoded.kind, ShareKind.node);
    expect(decoded.peers.single.address, 'relay.example.com:11010');
    expect(
      () => ShareDocument.decodeRoot({...root, 'kind': 'bundle'}),
      throwsFormatException,
    );
  });

  test('trims a name, drops a blank secret and deduplicates protocols', () {
    final decoded = ShareDocument.decode(
      jsonEncode({
        'v': shareDocumentVersion,
        'kind': 'network',
        'name': ' alpha ',
        'secret': '   ',
        'peers': [
          {
            'host': 'relay.example.com',
            'port': 11010,
            'protocols': ['tcp', 'tcp', 'udp'],
          },
        ],
      }),
    );

    expect(decoded.name, 'alpha');
    expect(decoded.hasSecret, isFalse);
    expect(decoded.peers.single.protocols, [
      NodeProtocol.tcp,
      NodeProtocol.udp,
    ]);
  });

  test('refuses malformed documents instead of accepting half of one', () {
    final base = sharedNetworkDocument().toJson();
    final peer = sharedNetworkDocument().peers.first.toJson();
    final node = sharedNodeDocument().toJson();
    String network(Map<String, Object?> changes) =>
        jsonEncode({...base, ...changes});
    String peerWith(Map<String, Object?> changes) => network({
      'peers': [
        {...peer, ...changes},
      ],
    });
    final noVersion = Map.of(base)..remove('v');
    final noName = Map.of(base)..remove('name');

    final invalid = <String, String>{
      'not JSON': 'nope',
      'not an object': '[]',
      'no version': jsonEncode(noVersion),
      'newer version': network({'v': shareDocumentVersion + 1}),
      'unknown kind': network({'kind': 'device'}),
      'network without a name': jsonEncode(noName),
      'network with a blank name': network({'name': '   '}),
      'name longer than 128 characters': network({'name': 'a' * 129}),
      'node share with a name': jsonEncode({...node, 'name': 'alpha'}),
      'node share with a secret': jsonEncode({...node, 'secret': 'secret'}),
      'node share with two peers': jsonEncode({
        ...node,
        'peers': [
          peer,
          {...peer, 'port': 443},
        ],
      }),
      'no peers': network({'peers': <Object?>[]}),
      'more than shareMaxPeers peers': network({
        'peers': List<Object?>.filled(shareMaxPeers + 1, peer),
      }),
      'peer is not an object': network({
        'peers': ['nope'],
      }),
      'peer without a host': peerWith({'host': null}),
      'peer with a blank host': peerWith({'host': '   '}),
      'host longer than 253 characters': peerWith({'host': 'a' * 254}),
      'host with whitespace': peerWith({'host': 'relay example.com'}),
      'host with a path': peerWith({'host': 'relay/example.com'}),
      'host with user info': peerWith({'host': 'user@relay.example.com'}),
      'host with a query': peerWith({'host': 'relay.example.com?x=1'}),
      'host with a fragment': peerWith({'host': 'relay.example.com#x'}),
      'host that is a host and port': peerWith({'host': 'evil.com:80'}),
      'host with a percent escape': peerWith({'host': 'a%41b'}),
      'host with an encoded slash': peerWith({'host': 'a%2Fb'}),
      'host that does not round-trip': peerWith({'host': '例子.com'}),
      'path without a leading slash': peerWith({'path': 'ws'}),
      'path longer than 256 characters': peerWith({'path': '/${'a' * 256}'}),
      'path with a query': peerWith({'path': '/ws?x=1'}),
      'path with a fragment': peerWith({'path': '/ws#x'}),
      'path with whitespace': peerWith({'path': '/w s'}),
      'path that does not round-trip': peerWith({'path': '/你好'}),
      'peer without a port': peerWith({'port': null}),
      'peer with port 0': peerWith({'port': 0}),
      'peer with port 65536': peerWith({'port': 65536}),
      'peer with a text port': peerWith({'port': '11010'}),
      'peer without protocols': peerWith({'protocols': <Object?>[]}),
      'peer with an unknown protocol': peerWith({
        'protocols': ['ftp'],
      }),
      'peer with a non-text protocol': peerWith({
        'protocols': [42],
      }),
      'public key longer than 512 characters': peerWith({
        'publicKey': 'k' * 513,
      }),
      'secret longer than 512 characters': network({'secret': 's' * 513}),
      'content larger than shareMaxBytes': jsonEncode({
        ...base,
        'padding': 'x' * (shareMaxBytes + 1),
      }),
    };

    invalid.forEach((description, content) {
      expect(
        () => ShareDocument.decode(content),
        throwsFormatException,
        reason: description,
      );
    });
  });
}

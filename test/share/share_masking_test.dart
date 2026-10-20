import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_flags.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_masking.dart';

import 'share_fixture.dart';

/// A network whose local-only values are all recognisable sentinels.
Network sentinelNetwork() => Network()
  ..networkName = 'alpha'
  ..networkSecret = ' s3cret '
  ..hostname = 'SENTINEL-hostname'
  ..ipv4 = '10.SENTINEL.0.7'
  ..ipv6 = 'SENTINEL::1'
  ..listeners = [Uri.parse('tcp://SENTINEL-listener.example.com:11010')]
  ..mappedListeners = [Uri.parse('udp://SENTINEL-mapped.example.com:11010')]
  ..exitNodes = ['SENTINEL-exit']
  ..routes = ['SENTINEL-route']
  ..socks5Proxy = Uri.parse('socks5://SENTINEL-proxy.example.com:1080')
  ..credentialFile = 'SENTINEL-credentials.json'
  ..acl = {'SENTINEL-acl': 'allow'}
  ..additionalConfiguration = {'SENTINEL-config': 1}
  ..createdAt = DateTime.utc(2020)
  ..flags = (NetworkFlags()..deviceName = 'SENTINEL-device')
  ..nodes = [
    Node(
      id: 'SENTINEL-node-id',
      url: Uri.parse('tcp://relay.example.com/x'),
      port: 11010,
      protocols: [NodeProtocol.tcp, NodeProtocol.tcp, NodeProtocol.udp],
      publicKey: 'public-key',
    ),
    Node(
      id: 'SENTINEL-node-2',
      url: Uri.parse('other.example.com'),
      port: 443,
      protocols: [NodeProtocol.wss],
    ),
  ];

void main() {
  test('shares only a network name, secret and peers', () {
    final document = shareNetwork(sentinelNetwork());

    expect(document.kind, ShareKind.network);
    expect(document.name, 'alpha');
    expect(document.secret, 's3cret');
    expect(document.peers.map((peer) => peer.address), [
      'relay.example.com:11010',
      'other.example.com:443',
    ]);
    expect(document.peers.first.protocols, [
      NodeProtocol.tcp,
      NodeProtocol.udp,
    ]);
    expect(document.peers.first.publicKey, 'public-key');
    expect(document.peers.first.path, '/x');
    expect(document.peers.last.path, isNull);
    expect(document.encode(), isNot(contains('SENTINEL')));
  });

  test('treats a blank network secret as absent', () {
    final document = shareNetwork(
      Network()
        ..networkSecret = '   '
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('relay.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    );

    expect(document.hasSecret, isFalse);
  });

  test('refuses to share a network without peers', () {
    expect(() => shareNetwork(Network()), throwsStateError);
  });

  test('shares a bookmark node without its local annotations', () {
    final bookmark = Bookmark(
      id: 'SENTINEL-bookmark-id',
      node: Node(
        id: 'SENTINEL-node-id',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
        publicKey: 'public-key',
      ),
      name: 'SENTINEL-name',
      description: 'SENTINEL-description',
      category: 'SENTINEL-category',
      tags: const ['SENTINEL-tag'],
      extensions: const {'SENTINEL-extension': true},
    );

    final document = shareBookmark(bookmark);

    expect(document.kind, ShareKind.node);
    expect(document.name, isNull);
    expect(document.peers.single.address, 'relay.example.com:11010');
    expect(document.peers.single.publicKey, 'public-key');
    expect(document.encode(), isNot(contains('SENTINEL')));
  });

  test('shares an authority-relative peer path', () {
    final bookmark = Bookmark(
      id: 'b1',
      node: Node(
        id: 'relay',
        url: Uri.parse('wss://relay.example.com/ws'),
        port: 443,
        protocols: const [NodeProtocol.wss],
      ),
    );

    final document = shareBookmark(bookmark);
    final peer = document.peers.single;

    expect(peer.host, 'relay.example.com');
    expect(peer.port, 443);
    expect(peer.path, '/ws');

    final imported = bookmarkFromShare(
      ShareDocument.decode(document.encode()),
      id: 'new-bookmark-id',
    );

    expect(imported.node.url.userInfo, isEmpty);
    expect(
      imported.node.endpoint(NodeProtocol.wss),
      Uri.parse('wss://relay.example.com:443/ws'),
    );
  });

  test('refuses a node whose address carries credentials', () {
    final node = Node(
      id: 'relay',
      url: Uri.parse('wss://user:pass@relay.example.com/ws'),
      port: 443,
      protocols: const [NodeProtocol.wss],
    );

    expect(() => sharedPeer(node), throwsStateError);
    expect(
      () => shareBookmark(Bookmark(id: 'b1', node: node)),
      throwsStateError,
    );
    expect(() => shareNetwork(Network()..nodes = [node]), throwsStateError);
  });

  test('keeps a shared peer path when importing', () {
    final network = networkFromShare(
      const ShareDocument(
        kind: ShareKind.network,
        name: 'alpha',
        peers: [
          SharedPeer(
            host: 'relay.example.com',
            port: 443,
            protocols: [NodeProtocol.wss],
            path: '/ws',
          ),
        ],
      ),
      takenNames: const [],
    );

    expect(
      network.nodes.single.endpoint(NodeProtocol.wss),
      Uri.parse('wss://relay.example.com:443/ws'),
    );
  });

  test('builds a fresh local network from a shared one', () {
    final network = networkFromShare(
      sharedNetworkDocument(),
      takenNames: const [],
    );

    expect(network.networkName, 'alpha');
    expect(network.networkSecret, 's3cret');
    expect(network.dhcp, isTrue);
    expect(network.nodes.map((node) => node.id), [
      'relay.example.com:11010',
      '::1:443',
    ]);
    expect(network.nodes.first.url, Uri.parse('relay.example.com'));
    expect(network.nodes.first.port, 11010);
    expect(network.nodes.first.protocols, [NodeProtocol.tcp, NodeProtocol.udp]);
    expect(network.nodes.first.publicKey, 'public-key');
    expect(network.hostname, isNull);
    expect(network.listeners, isEmpty);
    expect(network.acl, isNull);
    expect(network.credentialFile, isNull);
  });

  test('numbers a network name that is already taken', () {
    String nameFor(List<String> takenNames) => networkFromShare(
      sharedNetworkDocument(),
      takenNames: takenNames,
    ).networkName;

    expect(nameFor(const []), 'alpha');
    expect(nameFor(const ['alpha']), 'alpha (2)');
    expect(nameFor(const ['alpha', 'alpha (2)']), 'alpha (3)');
    expect(nameFor(const ['beta', 'alpha (2)']), 'alpha');
  });

  test('rejects a document of the wrong kind', () {
    expect(
      () => networkFromShare(sharedNodeDocument(), takenNames: const []),
      throwsArgumentError,
    );
    expect(
      () => bookmarkFromShare(sharedNetworkDocument(), id: 'new-bookmark-id'),
      throwsArgumentError,
    );
  });

  test('builds a fresh local bookmark from a shared node', () {
    final bookmark = bookmarkFromShare(
      sharedNodeDocument(),
      id: 'new-bookmark-id',
    );

    expect(bookmark.id, 'new-bookmark-id');
    expect(bookmark.name, 'relay.example.com');
    expect(bookmark.address, 'relay.example.com:11010');
    expect(bookmark.node.id, 'relay.example.com:11010');
    expect(bookmark.node.url, Uri.parse('relay.example.com'));
    expect(bookmark.node.protocols, [NodeProtocol.quic]);
    expect(bookmark.node.publicKey, 'public-key');
  });
}

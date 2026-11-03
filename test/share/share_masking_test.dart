import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_components.dart';
import 'package:yukari_core/models/network_flags.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/share/share_configs.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_masking.dart';
import 'package:yukari/share/share_options.dart';
import 'package:yukari/share/share_self_peer.dart';

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

  test('shares a bookmark node under its name, without its annotations', () {
    final bookmark = Bookmark(
      id: 'SENTINEL-bookmark-id',
      node: Node(
        id: 'SENTINEL-node-id',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
        publicKey: 'public-key',
      ),
      name: ' Relay One ',
      description: 'SENTINEL-description',
      category: 'SENTINEL-category',
      tags: const ['SENTINEL-tag'],
      extensions: const {'SENTINEL-extension': true},
    );

    final document = shareBookmark(bookmark);

    expect(document.kind, ShareKind.node);
    expect(document.name, 'Relay One');
    expect(document.peers.single.address, 'relay.example.com:11010');
    expect(document.peers.single.publicKey, 'public-key');
    expect(document.encode(), isNot(contains('SENTINEL')));
  });

  test('treats a blank bookmark name as absent', () {
    final document = shareBookmark(
      Bookmark(
        id: 'b1',
        node: Node(
          id: 'relay',
          url: Uri.parse('relay.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
        name: '   ',
      ),
    );

    expect(document.name, isNull);
    expect(document.toJson().containsKey('name'), isFalse);
  });

  test('clamps an over-long bookmark name, so its node stays shareable', () {
    final document = shareBookmark(
      Bookmark(
        id: 'b1',
        node: Node(
          id: 'relay',
          url: Uri.parse('relay.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
        name: 'n' * (shareMaxNameLength + 40),
      ),
    );

    expect(document.name, hasLength(shareMaxNameLength));
    // The receiver accepts the clamped name, so the sender shares the node
    // instead of reporting it unsupported.
    expect(
      ShareDocument.decode(document.encode()).name,
      hasLength(shareMaxNameLength),
    );
  });

  test('clamps a name without splitting a surrogate pair', () {
    final document = shareBookmark(
      Bookmark(
        id: 'b1',
        node: Node(
          id: 'relay',
          url: Uri.parse('relay.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
        // The 128th code unit is the high half of the emoji, so the clamp must
        // step back one or the name would end mid-character.
        name: '${'n' * (shareMaxNameLength - 1)}😀',
      ),
    );

    expect(document.name, 'n' * (shareMaxNameLength - 1));
    expect(ShareDocument.decode(document.encode()).name, document.name);
  });

  test('a shared bookmark keeps its name through the wire', () {
    final bookmark = Bookmark(
      id: 'b1',
      node: Node(
        id: 'relay',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
      name: 'Relay One',
    );

    final imported = bookmarkFromShare(
      ShareDocument.decode(shareBookmark(bookmark).encode()),
      id: 'new-bookmark-id',
    );

    expect(imported.name, 'Relay One');
    expect(imported.address, 'relay.example.com:11010');
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

  test('builds a fresh local bookmark under the shared node name', () {
    final bookmark = bookmarkFromShare(
      sharedNodeDocument(name: 'Relay One'),
      id: 'new-bookmark-id',
    );

    expect(bookmark.name, 'Relay One');
    expect(bookmark.address, 'relay.example.com:11010');
    expect(bookmark.node.id, 'relay.example.com:11010');
  });

  test('offers this device from the mapped listener before the local one', () {
    final peer = selfPeerOf(
      listenerNetwork(
        mapped: [Uri.parse('udp://198.51.100.7:11010')],
        local: [Uri.parse('tcp://198.51.100.8:11010')],
      ),
    );

    expect(peer?.address, '198.51.100.7:11010');
    expect(peer?.protocols, [NodeProtocol.udp]);
    expect(peer?.publicKey, isNull);
  });

  test('merges a later listener of the same address as one more protocol', () {
    final peer = selfPeerOf(
      listenerNetwork(
        mapped: [Uri.parse('tcp://198.51.100.7:11010')],
        local: [
          Uri.parse('udp://198.51.100.7:11010'),
          Uri.parse('tcp://198.51.100.7:11010'),
          Uri.parse('wss://198.51.100.9:443'),
        ],
      ),
    );

    expect(peer?.address, '198.51.100.7:11010');
    expect(peer?.protocols, [NodeProtocol.tcp, NodeProtocol.udp]);
  });

  test('publishes no self peer for an address nobody can dial', () {
    for (final host in [
      '0.0.0.0',
      '::',
      '127.0.0.1',
      '127.0.0.2',
      '::1',
      '::ffff:127.0.0.1',
      'localhost',
    ]) {
      final network = listenerNetwork(
        local: [Uri(scheme: 'tcp', host: host, port: 11010)],
      );
      expect(selfPeerOf(network), isNull, reason: host);
    }

    expect(selfPeerOf(listenerNetwork()), isNull);
    expect(
      selfPeerOf(
        listenerNetwork(local: [Uri.parse('tcp://user:pass@198.51.100.7:1')]),
      ),
      isNull,
      reason: 'a listener credential is never shared',
    );
  });

  test('keeps the listener path a websocket peer needs', () {
    final peer = selfPeerOf(
      listenerNetwork(local: [Uri.parse('wss://198.51.100.7:443/ws')]),
    );

    expect(peer?.address, '198.51.100.7:443');
    expect(peer?.path, '/ws');
    expect(peer?.protocols, [NodeProtocol.wss]);
  });

  test('keeps the first path while merging protocols of one address', () {
    final peer = selfPeerOf(
      listenerNetwork(
        mapped: [Uri.parse('wss://198.51.100.7:443/ws')],
        local: [Uri.parse('tcp://198.51.100.7:443')],
      ),
    );

    expect(peer?.protocols, [NodeProtocol.wss, NodeProtocol.tcp]);
    expect(peer?.path, '/ws');
  });

  test('shares a self peer the receiver reaches on the same path', () {
    final document = shareNetwork(
      listenerNetwork(local: [Uri.parse('wss://198.51.100.7:443/ws')]),
      options: (includeSelf: true, includeConfigs: false),
    );

    final imported = networkFromShare(
      ShareDocument.decode(document.encode()),
      takenNames: const [],
    );

    expect(
      imported.nodes.last.endpoint(NodeProtocol.wss),
      Uri.parse('wss://198.51.100.7:443/ws'),
    );
  });

  test('carries the public key secure mode generated', () {
    final key = base64.encode(List<int>.filled(32, 7));
    final network = listenerNetwork(local: const [])
      ..listeners = [Uri.parse('tcp://198.51.100.7:11010')]
      ..secureMode = SecureMode(enabled: true, localPublicKey: ' $key ');

    expect(selfPeerOf(network)?.publicKey, key);
  });

  test('offers this device without a key it cannot publish', () {
    for (final secureMode in [
      null,
      SecureMode(
        enabled: false,
        localPublicKey: base64.encode(List.filled(32, 7)),
      ),
      SecureMode(enabled: true),
      SecureMode(
        enabled: true,
        localPublicKey: base64.encode(List.filled(16, 7)),
      ),
      SecureMode(enabled: true, localPublicKey: 'not a key!'),
    ]) {
      final network = listenerNetwork(local: const [])
        ..listeners = [Uri.parse('tcp://198.51.100.7:11010')]
        ..secureMode = secureMode;

      final peer = selfPeerOf(network);
      expect(peer?.address, '198.51.100.7:11010');
      expect(peer?.publicKey, isNull, reason: '$secureMode');
    }
  });

  test('adds this device as an ordinary peer when asked', () {
    final network = listenerNetwork(
      local: [Uri.parse('tcp://198.51.100.7:11010')],
    );

    final document = shareNetwork(
      network,
      options: (includeSelf: true, includeConfigs: false),
    );

    expect(document.peers.map((peer) => peer.address), [
      'relay.example.com:11010',
      '198.51.100.7:11010',
    ]);
    // No marker field: an older receiver imports it as one more peer.
    final peers =
        (jsonDecode(document.encode()) as Map<String, Object?>)['peers']
            as List<Object?>;
    expect((peers.last as Map<String, Object?>).keys, [
      'host',
      'port',
      'protocols',
    ]);
  });

  test('does not add a peer the network already lists', () {
    final network = listenerNetwork(
      local: [Uri.parse('tcp://relay.example.com:11010')],
    );

    final document = shareNetwork(
      network,
      options: (includeSelf: true, includeConfigs: false),
    );

    expect(document.peers.map((peer) => peer.address), [
      'relay.example.com:11010',
    ]);
    expect(
      selfPeerForShare(network),
      isNull,
      reason: 'the switch must say what the share would do',
    );
  });

  test('offers this device only while the share has room for it', () {
    final network = listenerNetwork(
      local: [Uri.parse('tcp://198.51.100.7:11010')],
    );
    expect(selfPeerForShare(network), isNotNull);

    network.nodes = [
      for (var index = 0; index < shareMaxPeers; index++)
        Node(
          id: 'peer-$index',
          url: Uri.parse('relay$index.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
    ];

    expect(selfPeerForShare(network), isNull);
  });

  test('a share with no options changes nothing on the wire', () {
    final network = sentinelNetwork();

    final chosen = shareNetwork(network, options: noShareOptions);

    expect(chosen.encode(), shareNetwork(network).encode());
    expect(chosen.configs, isNull);
  });

  test('shares no configs until the sender asks for them', () {
    final network =
        listenerNetwork(local: [Uri.parse('tcp://198.51.100.7:11010')])
          ..flags = (NetworkFlags()
            ..noTun = true
            ..dnsZone = 'home.example.com.');
    // The network does differ from the defaults, so only the option can keep
    // the key off the wire.
    expect(configsOf(network), isNotNull);

    final plain = shareNetwork(network);

    expect(plain.configs, isNull);
    expect(plain.toJson().containsKey('configs'), isFalse);
    expect(
      plain.encode(),
      shareNetwork(network, options: noShareOptions).encode(),
    );
  });

  test('shares no configs for a network that runs at the defaults', () {
    final plain = listenerNetwork();

    final document = shareNetwork(
      plain,
      options: (includeSelf: false, includeConfigs: true),
    );

    expect(document.configs, isNull);
    expect(document.encode(), shareNetwork(plain).encode());
  });

  test('shares the zone only when the network answers Magic DNS', () {
    final zoneOnly = listenerNetwork()
      ..flags = (NetworkFlags()..dnsZone = 'home.example.com.');
    expect(configsOf(zoneOnly), isNull, reason: 'Magic DNS is off');

    final noTun = listenerNetwork()
      ..flags = (NetworkFlags()
        ..noTun = true
        ..acceptDns = true
        ..dnsZone = 'home.example.com.');
    expect(configsOf(noTun)?.dnsZone, isNull, reason: 'no TUN answers none');
  });

  test('shares No TUN, and never Magic DNS beside it', () {
    final document = shareNetwork(
      listenerNetwork()
        ..flags = (NetworkFlags()
          ..noTun = true
          ..acceptDns = true),
      options: (includeSelf: false, includeConfigs: true),
    );

    expect(document.configs?.noTun, isTrue);
    expect(document.configs?.acceptDns, isFalse);
    expect(document.configs?.dnsZone, isNull);
  });

  test('shares Magic DNS under the zone the network runs', () {
    final document = shareNetwork(
      listenerNetwork()
        ..flags = (NetworkFlags()
          ..acceptDns = true
          ..dnsZone = 'home.example.com.'),
      options: (includeSelf: false, includeConfigs: true),
    );

    expect(document.configs?.noTun, isFalse);
    expect(document.configs?.acceptDns, isTrue);
    expect(document.configs?.dnsZone, 'home.example.com.');
  });

  test('imports the configs a share carried', () {
    final network = networkFromShare(
      ShareDocument(
        kind: ShareKind.network,
        name: 'alpha',
        configs: const SharedConfigs(noTun: true, dnsZone: 'home.example.com.'),
        peers: sharedNetworkDocument().peers,
      ),
      takenNames: const [],
    );

    expect(network.flags.noTun, isTrue);
    expect(network.flags.acceptDns, isFalse);
    expect(network.flags.dnsZone, 'home.example.com.');
  });

  test('imports a share without configs at the defaults', () {
    final network = networkFromShare(
      sharedNetworkDocument(),
      takenNames: const [],
    );

    final defaults = NetworkFlags();
    expect(network.flags.noTun, defaults.noTun);
    expect(network.flags.acceptDns, defaults.acceptDns);
    expect(network.flags.dnsZone, defaults.dnsZone);
  });
}

/// A network with one saved peer and the listeners a test gives it, so the
/// self peer is the only thing that varies.
Network listenerNetwork({
  List<Uri> mapped = const [],
  List<Uri> local = const [],
}) => Network()
  ..networkName = 'alpha'
  ..mappedListeners = [...mapped]
  ..listeners = [...local]
  ..nodes = [
    Node(
      id: 'relay.example.com:11010',
      url: Uri.parse('relay.example.com'),
      port: 11010,
      protocols: const [NodeProtocol.tcp],
    ),
  ];

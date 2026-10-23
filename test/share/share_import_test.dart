import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/signals/bookmarks.dart' as saved;
import 'package:yukari/signals/networks.dart' as networks;
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_import.dart';
import 'package:yukari/share/share_masking.dart';
import 'package:yukari/share/share_options.dart';
import 'package:yukari/share/share_targets.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_flags.dart';
import 'package:yukari_core/models/node.dart';

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';
import 'share_fixture.dart';

void main() {
  test(
    'saves a shared network under a fresh key and numbers its name',
    () async {
      await seedWith({'n1': Network()..networkName = 'beta'});

      expect(await addSharedNetwork(sharedNetworkDocument()), 'alpha');
      await networks.settled();

      final firstKey = networks.networks.value.keys.singleWhere(
        (key) => key != 'n1',
      );
      final first = await persisted(firstKey);
      expect(first.networkName, 'alpha');
      expect(first.networkSecret, 's3cret');
      expect(first.nodes.map((node) => node.id), [
        'relay.example.com:11010',
        '::1:443',
      ]);

      expect(await addSharedNetwork(sharedNetworkDocument()), 'alpha (2)');
      await networks.settled();

      expect(networks.networks.value.length, 3);
      expect(
        networks.networks.value.values.map((network) => network.networkName),
        containsAll(['beta', 'alpha', 'alpha (2)']),
      );
    },
  );

  test('saves a shared node under a fresh bookmark id', () async {
    await seedBookmarks([testBookmark('b1', host: 'other.example.com')]);

    expect(
      await addSharedNode(sharedNodeDocument()),
      'relay.example.com:11010',
    );
    await saved.settled();

    final added = saved.bookmarks.value.last;
    expect(added.id, isNot('b1'));
    expect(added.address, 'relay.example.com:11010');
    expect(added.name, 'relay.example.com');
    expect(added.node.publicKey, 'public-key');
    expect(persistedBookmarks().last.address, 'relay.example.com:11010');
  });

  test('saves a shared node under the name it arrived with', () async {
    await seedBookmarks([testBookmark('b1', host: 'other.example.com')]);

    expect(
      await addSharedNode(sharedNodeDocument(name: 'Relay One')),
      'relay.example.com:11010',
    );
    await saved.settled();

    final added = saved.bookmarks.value.last;
    expect(added.name, 'Relay One');
    expect(added.address, 'relay.example.com:11010');
    expect(persistedBookmarks().last.name, 'Relay One');
  });

  test('a shared node name never hides a saved address', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com', port: 11010),
    ]);

    expect(await addSharedNode(sharedNodeDocument(name: 'Relay One')), isNull);
    await saved.settled();

    expect(saved.bookmarks.value.length, 1);
    expect(saved.bookmarks.value.single.id, 'b1');
  });

  test('ignores a shared node whose address is already saved', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com', port: 11010),
    ]);

    expect(await addSharedNode(sharedNodeDocument()), isNull);
    await saved.settled();

    expect(saved.bookmarks.value.length, 1);
    expect(persistedBookmarks().length, 1);
  });

  test('adds a mixed batch and counts what it did', () async {
    final saved = <ShareDocument>[];
    final importer = ShareImporter(
      addNetwork: (document) async {
        saved.add(document);
        return document.name!;
      },
      addNode: (document) async => null,
    );
    final documents = [
      networkShare('alpha'),
      networkShare('beta'),
      sharedNodeDocument(),
    ];

    final summary = await addSharedDocuments(documents, importer: importer);

    expect(summary, (added: 2, duplicates: 1, failed: 0));
    expect(saved.map((document) => document.name), ['alpha', 'beta']);
  });

  test('counts a failed item and still saves the rest', () async {
    final saved = <String>[];
    final importer = ShareImporter(
      addNetwork: (document) async {
        if (document.name == 'beta') throw StateError('disk');
        saved.add(document.name!);
        return document.name!;
      },
      addNode: (document) async => fail('no node is in this batch'),
    );

    final summary = await addSharedDocuments([
      networkShare('alpha'),
      networkShare('beta'),
      networkShare('gamma'),
    ], importer: importer);

    expect(summary, (added: 2, duplicates: 0, failed: 1));
    expect(saved, ['alpha', 'gamma']);
  });

  test('adds nothing from an empty batch', () async {
    final importer = ShareImporter(
      addNetwork: (document) async => fail('nothing to add'),
      addNode: (document) async => fail('nothing to add'),
    );

    expect(await addSharedDocuments(const [], importer: importer), (
      added: 0,
      duplicates: 0,
      failed: 0,
    ));
  });

  test('resolves the share target of a saved network', () async {
    await seedWith({
      'n1': Network()
        ..networkName = 'alpha'
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('relay.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    });

    final target = resolveShareTarget(ShareKind.network, 'n1');

    expect(target.reason, isNull);
    expect(target.documents, hasLength(1));
    expect(target.documents.single.kind, ShareKind.network);
    expect(target.documents.single.name, 'alpha');
    expect(
      target.documents.single.peers.single.address,
      'relay.example.com:11010',
    );
  });

  test('reports a missing or peerless network', () async {
    await seedWith({'n1': Network()..networkName = 'alpha'});

    expect(
      resolveShareTarget(ShareKind.network, 'n1').reason,
      ShareUnavailableReason.networkWithoutPeers,
    );
    expect(
      resolveShareTarget(ShareKind.network, 'missing').reason,
      ShareUnavailableReason.networkMissing,
    );
  });

  test('reports which extras a network can add', () async {
    Network networkWith({List<Uri> listeners = const []}) => Network()
      ..networkName = 'alpha'
      ..listeners = [...listeners]
      ..nodes = [
        Node(
          id: 'peer',
          url: Uri.parse('relay.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
      ];

    await seedWith({
      'plain': networkWith(),
      'dialable': networkWith(
        listeners: [Uri.parse('tcp://198.51.100.7:11010')],
      ),
      'listed': networkWith(
        listeners: [Uri.parse('tcp://relay.example.com:11010')],
      ),
      'configs': networkWith()..flags = (NetworkFlags()..noTun = true),
    });

    expect(
      resolveShareTarget(ShareKind.network, 'plain').extras,
      noShareExtras,
    );
    expect(resolveShareTarget(ShareKind.network, 'dialable').extras, (
      selfPeer: true,
      configs: false,
    ));
    expect(resolveShareTarget(ShareKind.network, 'configs').extras, (
      selfPeer: false,
      configs: true,
    ));
    expect(
      resolveShareTarget(ShareKind.network, 'listed').extras,
      noShareExtras,
      reason: 'the listener is a peer the share already carries',
    );
  });

  test('reports no extras for a node share', () async {
    await seedBookmarks([testBookmark('b1')]);

    expect(resolveShareTarget(ShareKind.node, 'b1').extras, noShareExtras);
  });

  test('resolving with options adds this device and its configs', () async {
    await seedWith({
      'n1': Network()
        ..networkName = 'alpha'
        ..listeners = [Uri.parse('tcp://198.51.100.7:11010')]
        ..flags = (NetworkFlags()..noTun = true)
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('relay.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    });

    final chosen = resolveShareTarget(
      ShareKind.network,
      'n1',
      options: (includeSelf: true, includeConfigs: true),
    );

    expect(chosen.documents.single.peers.map((peer) => peer.address), [
      'relay.example.com:11010',
      '198.51.100.7:11010',
    ]);
    expect(chosen.documents.single.configs?.noTun, isTrue);
    expect(
      resolveShareTarget(ShareKind.network, 'n1').documents.single.peers,
      hasLength(1),
      reason: 'a share with neither option carries the peers it always did',
    );
  });

  test('a network keeps its configs off the wire until asked', () async {
    await seedWith({
      'n1': Network()
        ..networkName = 'alpha'
        ..listeners = [Uri.parse('tcp://198.51.100.7:11010')]
        ..flags = (NetworkFlags()
          ..noTun = true
          ..dnsZone = 'home.example.com.')
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('relay.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    });

    final plain = resolveShareTarget(ShareKind.network, 'n1');

    expect(plain.documents.single.configs, isNull);
    expect(plain.documents.single.toJson().containsKey('configs'), isFalse);
    final chosen = resolveShareTarget(
      ShareKind.network,
      'n1',
      options: (includeSelf: false, includeConfigs: true),
    ).documents.single.configs;
    expect(chosen?.noTun, isTrue);
    expect(
      chosen?.dnsZone,
      isNull,
      reason: 'the network answers no Magic DNS, so its zone says nothing',
    );
  });

  test('a network with nothing to add keeps today\'s document', () async {
    Network plain() => Network()
      ..networkName = 'alpha'
      ..nodes = [
        Node(
          id: 'peer',
          url: Uri.parse('relay.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
      ];
    await seedWith({'n1': plain()});

    final chosen = resolveShareTarget(
      ShareKind.network,
      'n1',
      options: (includeSelf: true, includeConfigs: true),
    );

    expect(chosen.documents.single.encode(), shareNetwork(plain()).encode());
  });

  test('imports the sender as one more initial node', () async {
    await seedWith({
      'n1': Network()
        ..networkName = 'gamma'
        ..listeners = [Uri.parse('tcp://198.51.100.7:11010')]
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('relay.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    });

    final target = resolveShareTarget(
      ShareKind.network,
      'n1',
      options: (includeSelf: true, includeConfigs: false),
    );
    expect(await addSharedNetwork(target.documents.single), 'gamma (2)');
    await networks.settled();

    final importedKey = networks.networks.value.entries
        .singleWhere((entry) => entry.value.networkName == 'gamma (2)')
        .key;
    final imported = await persisted(importedKey);
    expect(imported.nodes.map((node) => node.id), [
      'relay.example.com:11010',
      '198.51.100.7:11010',
    ]);
  });

  test('reports a network the receiver would refuse as unsupported', () async {
    Network networkWith(int peers) => Network()
      ..networkName = 'alpha'
      ..nodes = [
        for (var index = 0; index < peers; index++)
          Node(
            id: 'peer-$index',
            url: Uri.parse('relay$index.example.com'),
            port: 11010,
            protocols: const [NodeProtocol.tcp],
          ),
      ];

    await seedWith({'many': networkWith(shareMaxPeers + 1)});
    final tooManyPeers = resolveShareTarget(ShareKind.network, 'many');
    expect(tooManyPeers.documents, isEmpty);
    expect(tooManyPeers.reason, ShareUnavailableReason.unsupported);

    await seedWith({
      'longSecret': Network()
        ..networkName = 'alpha'
        ..networkSecret = 's' * 513
        ..nodes = [networkWith(1).nodes.single],
    });
    final tooLongSecret = resolveShareTarget(ShareKind.network, 'longSecret');
    expect(tooLongSecret.documents, isEmpty);
    expect(tooLongSecret.reason, ShareUnavailableReason.unsupported);
  });

  test('reports a target that needs credentials as unsupported', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'https://user:pass@relay.example.com'),
    ]);

    final bookmark = resolveShareTarget(ShareKind.node, 'b1');

    expect(bookmark.documents, isEmpty);
    expect(bookmark.reason, ShareUnavailableReason.unsupported);

    await seedWith({
      'n1': Network()
        ..networkName = 'alpha'
        ..nodes = [
          Node(
            id: 'peer',
            url: Uri.parse('https://user:pass@relay.example.com'),
            port: 443,
            protocols: const [NodeProtocol.tcp],
          ),
        ],
    });

    final network = resolveShareTarget(ShareKind.network, 'n1');

    expect(network.documents, isEmpty);
    expect(network.reason, ShareUnavailableReason.unsupported);
  });

  test('resolves the share target of a user and a built-in bookmark', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com', port: 11010),
    ]);

    final user = resolveShareTarget(ShareKind.node, 'b1');

    expect(user.reason, isNull);
    expect(user.documents, hasLength(1));
    expect(user.documents.single.kind, ShareKind.node);
    expect(
      user.documents.single.peers.single.address,
      'relay.example.com:11010',
    );

    final builtin = resolveShareTarget(
      ShareKind.node,
      builtinBookmarks.first.id,
    );

    expect(builtin.documents.single.peers.single.address, '225284.xyz:11010');
    expect(
      resolveShareTarget(ShareKind.node, 'missing').reason,
      ShareUnavailableReason.bookmarkMissing,
    );
  });
}

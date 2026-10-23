import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/signals/bookmarks.dart' as saved;
import 'package:yukari/signals/networks.dart' as networks;
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_import.dart';
import 'package:yukari/share/share_targets.dart';
import 'package:yukari_core/models/network.dart';
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

    final summary = await addSharedDocuments(
      [networkShare('alpha'), networkShare('beta'), networkShare('gamma')],
      importer: importer,
    );

    expect(summary, (added: 2, duplicates: 0, failed: 1));
    expect(saved, ['alpha', 'gamma']);
  });

  test('adds nothing from an empty batch', () async {
    final importer = ShareImporter(
      addNetwork: (document) async => fail('nothing to add'),
      addNode: (document) async => fail('nothing to add'),
    );

    expect(
      await addSharedDocuments(const [], importer: importer),
      (added: 0, duplicates: 0, failed: 0),
    );
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
    expect(target.documents.single.peers.single.address, 'relay.example.com:11010');
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
    expect(user.documents.single.peers.single.address, 'relay.example.com:11010');

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

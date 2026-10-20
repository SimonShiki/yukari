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
    expect(target.document, isNotNull);
    expect(target.document!.kind, ShareKind.network);
    expect(target.document!.name, 'alpha');
    expect(target.document!.peers.single.address, 'relay.example.com:11010');
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
    expect(tooManyPeers.document, isNull);
    expect(tooManyPeers.reason, ShareUnavailableReason.unsupported);

    await seedWith({
      'longSecret': Network()
        ..networkName = 'alpha'
        ..networkSecret = 's' * 513
        ..nodes = [networkWith(1).nodes.single],
    });
    final tooLongSecret = resolveShareTarget(ShareKind.network, 'longSecret');
    expect(tooLongSecret.document, isNull);
    expect(tooLongSecret.reason, ShareUnavailableReason.unsupported);
  });

  test('reports a target that needs credentials as unsupported', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'https://user:pass@relay.example.com'),
    ]);

    final bookmark = resolveShareTarget(ShareKind.node, 'b1');

    expect(bookmark.document, isNull);
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

    expect(network.document, isNull);
    expect(network.reason, ShareUnavailableReason.unsupported);
  });

  test('resolves the share target of a user and a built-in bookmark', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com', port: 11010),
    ]);

    final user = resolveShareTarget(ShareKind.node, 'b1');

    expect(user.reason, isNull);
    expect(user.document, isNotNull);
    expect(user.document!.kind, ShareKind.node);
    expect(user.document!.peers.single.address, 'relay.example.com:11010');

    final builtin = resolveShareTarget(
      ShareKind.node,
      builtinBookmarks.first.id,
    );

    expect(builtin.document!.peers.single.address, '225284.xyz:11010');
    expect(
      resolveShareTarget(ShareKind.node, 'missing').reason,
      ShareUnavailableReason.bookmarkMissing,
    );
  });
}

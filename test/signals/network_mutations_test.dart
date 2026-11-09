import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari_core/models/network.dart';

import '../networks_fixture.dart';

void main() {
  test(
    'queued updates read the preceding mutation and preserve order',
    () async {
      final store = await seedWith({'n1': Network()..networkName = 'alpha'});
      await Future.wait([
        saved.addNetwork('n2', Network()..networkName = 'beta'),
        saved.updateNetwork('n1', Network()..networkName = 'renamed'),
        saved.reorderNetworks(0, 2),
        saved.deleteNetwork('n2'),
      ]);
      await saved.settled();

      expect(saved.networks.peek().keys, ['n1']);
      expect(saved.networks.peek()['n1']!.networkName, 'renamed');
      final loaded = await store.load();
      expect(loaded.keys, ['n1']);
      expect(loaded['n1']!.networkName, 'renamed');
      expect(() => saved.networks.peek().clear(), throwsUnsupportedError);
    },
  );

  test(
    'failed persistence restores the snapshot and later writes succeed',
    () async {
      final store = await seedWith({'n1': Network()..networkName = 'alpha'});
      final before = saved.networks.peek();
      await store.file.delete();
      await Directory(store.file.path).create();

      await expectLater(
        saved.updateNetwork('n1', Network()..networkName = 'failed'),
        throwsA(isA<FileSystemException>()),
      );
      expect(saved.networks.peek(), same(before));

      await Directory(store.file.path).delete();
      await saved.addNetwork('n2', Network()..networkName = 'beta');
      await saved.settled();
      final loaded = await store.load();
      expect(loaded.keys, ['n1', 'n2']);
      expect(loaded['n1']!.networkName, 'alpha');
    },
  );

  test('validation errors do not block the next queued mutation', () async {
    await seedNetworks();
    final duplicate = saved.addNetwork('n1', Network());
    final rejected = expectLater(duplicate, throwsStateError);
    final next = saved.deleteNetwork('n2');

    await rejected;
    await next;
    await saved.settled();

    expect(saved.networks.peek().keys, ['n1']);
  });
}

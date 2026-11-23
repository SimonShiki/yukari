import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../networks_fixture.dart';

void main() {
  Network named(String name) => Network()..networkName = name;

  test('saves and loads networks in order', () async {
    final store = temporaryStore();
    await store.save({'b': named('beta'), 'a': named('alpha')});

    final loaded = await NetworkStore(store.file, readOnly: true).load();
    expect(loaded.keys, ['b', 'a']);
    expect(loaded['a']!.networkName, 'alpha');
  });

  test('loads legacy networks.json missing newer fields with mutable defaults', () async {
    final store = temporaryStore();
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString(
      jsonEncode({
        'legacy': {
          'networkName': 'old-net',
          'dhcp': false,
          'ipv4': '10.144.144.2/24',
          'nodes': [
            {'name': 'relay', 'url': 'tcp://example.com:11010'},
          ],
          'flags': {'mtu': 1400},
        },
      }),
    );

    final loaded = await store.load();
    final network = loaded['legacy']!;
    expect(network.networkName, 'old-net');
    expect(network.dhcp, isFalse);
    expect(network.ipv4, '10.144.144.2/24');
    expect(network.dhcpv6, isFalse);
    expect(network.dhcpIpv6Cidr, isNull);
    expect(network.dns, isNull);
    expect(network.ipv6PublicAddressProvider, isFalse);
    expect(network.ipv6PublicAddressAuto, isFalse);
    expect(network.tcpStunServers, isEmpty);
    expect(network.stunServersV6, isEmpty);
    expect(network.managedCredentials, isEmpty);
    expect(network.autoStart, isFalse);
    expect(network.flags.mtu, 1400);
    expect(network.nodes.single.url.toString(), 'tcp://example.com:11010');

    // Collections must remain mutable because the editor mutates them in place.
    network.nodes.add(
      Node(name: 'second', url: Uri.parse('udp://example.com:11010')),
    );
    network.additionalFlags['custom'] = true;
    network.additionalConfiguration['extra'] = 1;
    expect(network.nodes, hasLength(2));
    expect(network.additionalFlags['custom'], isTrue);
    expect(network.additionalConfiguration['extra'], 1);
  });

  test('Network.fromJson({}) populates all defaults and mutable collections', () {
    final network = Network.fromJson({});
    expect(network.networkName, 'youkai-boundaries');
    expect(network.dhcp, isTrue);
    expect(network.dhcpv6, isFalse);
    expect(network.autoStart, isFalse);
    expect(network.flags.mtu, 1380);
    expect(network.createdAt, isNotNull);
    expect(network.updatedAt, isNotNull);

    network.nodes.add(
      Node(name: 'peer', url: Uri.parse('tcp://example.com:11010')),
    );
    network.listeners.add(Uri.parse('tcp://0.0.0.0:11010'));
    network.additionalFlags['k'] = 'v';
    network.additionalConfiguration['k'] = 'v';
    expect(network.nodes, hasLength(1));
    expect(network.listeners, hasLength(1));
  });

  test('a missing file holds no networks', () async {
    expect(await temporaryStore().load(), isEmpty);
  });

  test('a read-only store refuses to write', () async {
    final store = NetworkStore(temporaryStore().file, readOnly: true);
    expect(() => store.save({}), throwsStateError);
  });

  group('secrets stay private', () {
    int mode(File file) => file.statSync().mode & 0x1FF;

    test('a save is readable by its owner alone', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')..networkSecret = 'secret'});

      expect(mode(store.file), 0x180 /* 0600 */);
      expect(store.file.parent.listSync().map((entry) => entry.path), [
        store.file.path,
      ], reason: 'no temporary file is left behind');
    });

    test('a save replaces a symlink rather than writing through it', () async {
      final store = temporaryStore();
      final victim = File('${store.file.parent.path}/victim')
        ..writeAsStringSync('keep');
      Link(store.file.path).createSync(victim.path);

      await store.save({'a': named('alpha')});

      expect(victim.readAsStringSync(), 'keep');
      expect(FileSystemEntity.isLinkSync(store.file.path), isFalse);
    });

    test('loading tightens a file an older version left readable', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')});
      await Process.run('chmod', ['644', store.file.path]);

      await store.load();

      expect(mode(store.file), 0x180 /* 0600 */);
    });

    test('the read-only service leaves the mode alone', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')});
      await Process.run('chmod', ['644', store.file.path]);

      await NetworkStore(store.file, readOnly: true).load();

      expect(mode(store.file), 0x1A4 /* 0644 */);
    });
  }, skip: Platform.isWindows ? 'Windows has no file modes' : false);
}

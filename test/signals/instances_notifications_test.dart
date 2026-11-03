import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari/signals/instance_logs.dart';
import 'package:yukari/signals/instances.dart';
import 'package:yukari/signals/networks.dart' as saved;

import '../fake_backend.dart';
import '../networks_fixture.dart';
import '../system/instance_info.dart';

void main() {
  setUp(seedNetworks);

  test('identical polls keep the map and do not notify subscribers', () async {
    final revision = instancesRevision.peek();
    final backend = CountingBackend(collected: () => {'alpha': _info()});
    var updates = 0;
    addTearDown(
      effect(() {
        instances.value;
        updates++;
      }),
    );

    await refreshInstances(backend);
    final first = instances.peek();
    await refreshInstances(backend);

    expect(backend.collects, 2);
    expect(updates, 2, reason: 'initial subscription and first result only');
    expect(instances.peek(), same(first));
    expect(instancesRevision.peek(), revision + 2);
  });

  test('an empty first result still marks the store as loaded', () async {
    var updates = 0;
    var loadedUpdates = 0;
    addTearDown(
      effect(() {
        instances.value;
        updates++;
      }),
    );
    addTearDown(
      effect(() {
        instancesLoaded.value;
        loadedUpdates++;
      }),
    );

    await refreshInstances(FakeBackend());
    await refreshInstances(FakeBackend());
    forgetInstances(['missing']);

    expect(instancesLoaded.peek(), isTrue);
    expect(loadedUpdates, 2);
    expect(updates, 1);
  });

  test('polls still record logs when the instance data is unchanged', () async {
    const event = '{"time":"2024-01-01T00:00:00Z","event":"TunDeviceError"}';
    clearInstanceLogs('n1');
    addTearDown(() => clearInstanceLogs('n1'));
    final backend = FakeBackend(
      collected: () => {
        'alpha': _info()..['events'] = [event],
      },
    );
    await refreshInstances(backend);
    final first = instances.peek();
    clearInstanceLogs('n1');

    await refreshInstances(backend);

    expect(instances.peek(), same(first));
    expect(instanceLogs('n1').peek().single.raw, event);
  });

  test('a changed network keeps the other instance object stable', () async {
    var beta = _info();
    final backend = FakeBackend(
      collected: () => {'alpha': _info(), 'beta': beta},
    );
    await refreshInstances(backend);
    final first = instances.peek();

    beta = _info()..['running'] = false;
    await refreshInstances(backend);

    expect(instances.peek()['n1'], same(first['n1']));
    expect(instances.peek()['n2'], isNot(same(first['n2'])));
    forgetInstances(['n2']);
    expect(instances.peek()['n1'], same(first['n1']));
  });

  test('saved configuration changes and reordering are published', () async {
    final backend = FakeBackend(
      collected: () => {'alpha': _info(), 'beta': _info()},
    );
    await refreshInstances(backend);
    final first = instances.peek()['n1'];
    final edited = saved.networks.peek()['n1']!.copy()..flags.noTun = true;
    await saved.updateNetwork('n1', edited);
    await refreshInstances(backend);
    expect(instances.peek()['n1'], isNot(same(first)));
    expect(instances.peek()['n1']!.network.flags.noTun, isTrue);

    await saved.reorderNetworks(0, 2);
    await refreshInstances(backend);
    expect(instances.peek().keys, ['n2', 'n1']);
  });

  test(
    'peer order changes are published even with equal traffic totals',
    () async {
      final peers = [instancePeer(), instancePeer(rx: 2000, tx: 1000)];
      var info = instanceInfo(peers: peers);
      final backend = FakeBackend(collected: () => {'alpha': info});
      await refreshInstances(backend);
      final first = instances.peek();

      info = instanceInfo(peers: peers.reversed.toList());
      await refreshInstances(backend);

      expect(instances.peek(), isNot(same(first)));
      expect(instances.peek()['n1']!.peers.first.rxBytes, 2000);
    },
  );

  final changes = <String, Object?>{
    'running': false,
    'error_msg': 'failed',
    'events': ['{"time":"2024-01-01T00:00:00Z","event":"TunDeviceError"}'],
    'my_node_info': null,
    'my_node_info.peer_id': 9,
    'my_node_info.hostname': 'renamed',
    'my_node_info.version': 'new-version',
    'my_node_info.virtual_ipv4.address.addr': 1,
    'my_node_info.stun_info.udp_nat_type': 'FullCone',
    'peer_route_pairs': [],
    'peer_route_pairs.0.route.peer_id': '9',
    'peer_route_pairs.0.route.hostname': 'renamed',
    'peer_route_pairs.0.route.ipv4_addr.address.addr': 1,
    'peer_route_pairs.0.route.stun_info': {'udp_nat_type': 'FullCone'},
    'peer_route_pairs.0.route.next_hop_peer_id': '2',
    'peer_route_pairs.0.peer.conns.0.peer_identity_type': 'Credential',
    'peer_route_pairs.0.peer.conns.0.secure_auth_level': 'PeerVerified',
    'peer_route_pairs.0.peer.conns.0.tunnel': {'tunnel_type': 'quic'},
    'peer_route_pairs.0.peer.conns.0.stats.latency_us': '1000',
    'peer_route_pairs.0.peer.conns.0.stats.rx_bytes': '1001',
    'peer_route_pairs.0.peer.conns.0.stats.tx_bytes': '2001',
    'peer_route_pairs.0.peer.conns.0.stats.rx_packets': '1',
    'peer_route_pairs.0.peer.conns.0.stats.tx_packets': '1',
  };
  for (final change in changes.entries) {
    test('publishes a change to ${change.key}', () async {
      final info = _info();
      final backend = FakeBackend(collected: () => {'alpha': info});
      await refreshInstances(backend);
      final first = instances.peek();

      _replace(info, change.key, change.value);
      await refreshInstances(backend);

      expect(instances.peek(), isNot(same(first)));
      expect(instances.peek()['n1'], isNot(same(first['n1'])));
      final updated = instances.peek();
      await refreshInstances(backend);
      expect(instances.peek(), same(updated));
    });
  }
}

Map<String, Object?> _info() =>
    jsonDecode(jsonEncode(instanceInfo(peers: [instancePeer()])))
        as Map<String, Object?>;

void _replace(Map<String, Object?> info, String path, Object? value) {
  final keys = path.split('.');
  Object? parent = info;
  for (final key in keys.take(keys.length - 1)) {
    parent = switch (parent) {
      Map<String, Object?> map => map[key],
      List<Object?> list => list[int.parse(key)],
      _ => throw StateError('Invalid fixture path $path'),
    };
  }
  (parent as Map<String, Object?>)[keys.last] = value;
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/models/instance.dart';
import 'package:yukari/models/network.dart';
import 'package:yukari/models/peer.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/utils/stun_probe.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  setUp(seedNetworks);

  HomeController controller({
    required FakeBackend backend,
    Future<NatProbe> Function()? probe,
    Future<int?> Function()? service,
  }) {
    final created = HomeController(
      backend: backend,
      probe:
          probe ??
          () async => const NatProbe(
            publicAddress: '203.0.113.7',
            natType: NatType.portRestricted,
          ),
      probeServiceVersion: service ?? () async => 1,
    );
    addTearDown(created.dispose);
    return created;
  }

  test(
    'reads instances, the EasyTier version and the Magic DNS host',
    () async {
      final network = saved.networks.value['n1']!;
      network.hostname = 'alpha-host';
      network.flags.acceptDns = true;
      await saved.updateNetwork('n1', network);
      final home = controller(
        backend: FakeBackend(
          collected: () => {
            'alpha': _info(peers: [_peer(rx: 1000, tx: 2000)]),
          },
        ),
      );

      await home.refresh();
      await home.checkServiceVersion();

      expect(home.refreshed.value, isTrue);
      expect(home.savedCount.value, 2);
      expect(home.runningCount.value, 1);
      expect(home.runningNames.value, 'alpha');
      expect(home.easyTierVersion.value, '2.7.0-1649ec00');
      expect(home.serviceVersion.value, 1);
      expect(home.address.value, '10.144.0.2');
      expect(home.addressKind.value, AddressKind.virtual);
      expect(home.addressSupporting.value, 'alpha-host.et.net · alpha');
      expect(home.addressMoreCount.value, 0);
      expect(home.addressTooltip.value, '10.144.0.2  alpha-host.et.net  alpha');
    },
  );

  test('an EasyTier NAT type wins over the STUN probe', () async {
    final home = controller(
      backend: FakeBackend(
        collected: () => {'alpha': _info(natType: 'Symmetric')},
      ),
      probe: () async => const NatProbe(
        publicAddress: '203.0.113.7',
        natType: NatType.fullCone,
      ),
    );

    await home.refresh();
    await home.detectNat();

    expect(home.natType.value, NatType.symmetric);
    expect(home.natReportedByEasytier.value, isTrue);
  });

  test('the STUN probe answers when no instance reports a NAT type', () async {
    final home = controller(backend: FakeBackend(collected: () => const {}));

    await home.refresh();
    await home.detectNat();

    expect(home.natType.value, NatType.portRestricted);
    expect(home.natReportedByEasytier.value, isFalse);
    expect(home.addressKind.value, AddressKind.public);
    expect(home.address.value, '203.0.113.7');
  });

  test('a failed probe records an unknown NAT without an address', () async {
    final home = controller(
      backend: FakeBackend(collected: () => const {}),
      probe: () async => throw StateError('no answer'),
    );

    await home.refresh();
    await home.detectNat();

    expect(home.natType.value, NatType.unknown);
    expect(home.addressKind.value, AddressKind.unavailable);
    expect(home.address.value, isNull);
  });

  test('detectNat is a no-op while a probe is in flight', () async {
    final gate = Completer<void>();
    var calls = 0;
    final home = controller(
      backend: FakeBackend(collected: () => const {}),
      probe: () async {
        calls++;
        await gate.future;
        return const NatProbe(publicAddress: null, natType: NatType.unknown);
      },
      service: () async => null,
    );

    final detection = home.detectNat();
    expect(home.probing.value, isTrue);
    await home.detectNat();
    expect(calls, 1);

    gate.complete();
    await detection;
    expect(home.probing.value, isFalse);
  });

  test('measures traffic rates between two refreshes', () async {
    final infos = <String, Object?>{
      'alpha': _info(peers: [_peer(rx: 1000, tx: 2000)]),
    };
    final home = controller(backend: FakeBackend(collected: () => infos));

    await home.refresh();
    expect(home.trafficIdle.value, isFalse);
    expect(home.totalReceived.value, 1000);
    expect(home.totalSent.value, 2000);
    expect(home.receiveRate.value, 0, reason: 'the first sample has no rate');
    expect(home.sendRate.value, 0);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    infos['alpha'] = _info(peers: [_peer(rx: 3000, tx: 5000)]);
    await home.refresh();
    expect(home.receiveRate.value, greaterThan(0));
    expect(home.sendRate.value, greaterThan(home.receiveRate.value));
    expect(home.totalReceived.value, 3000);

    // A reconnected peer restarts its counters; rates must not go negative.
    infos['alpha'] = _info(peers: [_peer(rx: 10, tx: 10)]);
    await home.refresh();
    expect(home.receiveRate.value, 0);
    expect(home.sendRate.value, 0);

    // Nothing running: no traffic at all.
    infos.clear();
    await home.refresh();
    expect(home.trafficIdle.value, isTrue);
    expect(home.totalReceived.value, 0);

    // Rates restart from zero after the last instance stopped.
    infos['alpha'] = _info(peers: [_peer(rx: 9000, tx: 9000)]);
    await home.refresh();
    expect(home.receiveRate.value, 0);
    expect(home.totalReceived.value, 9000);
  });

  test('marks refreshed whether or not the collection fails', () async {
    var failing = true;
    final home = controller(
      backend: FakeBackend(
        collected: () =>
            failing ? throw StateError('offline') : {'alpha': _info()},
      ),
    );

    await home.refresh();

    expect(home.refreshed.value, isTrue);
    expect(home.runningCount.value, 0);
    expect(home.trafficIdle.value, isTrue);
    expect(home.addressKind.value, AddressKind.waiting);

    // The failure must not leave the reentrancy guard set.
    failing = false;
    await home.refresh();

    expect(home.runningCount.value, 1);
    expect(home.refreshed.value, isTrue);
  });

  test(
    'a refresh that throws while measuring still releases the guard',
    () async {
      final network = saved.networks.value['n1']!;
      final backend = _ScriptedBackend([
        () async => _ExplodingInstances(),
        () async => {
          'n1': Instance(
            network: network,
            status: InstanceStatus.running,
            events: const [],
            myself: null,
            peers: const [],
          ),
        },
      ]);
      final home = controller(backend: backend);

      await expectLater(home.refresh(), throwsA(isA<StateError>()));

      expect(home.refreshed.value, isTrue, reason: 'the finally must mark it');
      await home.refresh();
      expect(backend.calls, 2, reason: 'a later refresh must still run');
      expect(home.runningCount.value, 1);
    },
  );

  test('disposing during a refresh leaves no stuck guard or error', () async {
    final gate = Completer<void>();
    final backend = _ScriptedBackend([
      () async {
        await gate.future;
        return const <String, Instance>{};
      },
    ]);
    final home = controller(backend: backend);

    final inFlight = home.refresh();
    home.dispose();
    gate.complete();
    await inFlight;

    await home.refresh();
    expect(backend.calls, 1);
  });

  test('a network without a hostname has no Magic DNS host', () async {
    final network = saved.networks.value['n1']!;
    network.flags.acceptDns = true;
    await saved.updateNetwork('n1', network);
    final home = controller(
      backend: FakeBackend(
        // The instance reports a hostname; the network config does not.
        collected: () => {'alpha': _info(hostname: 'alpha-node')},
      ),
    );

    await home.refresh();

    expect(home.addressSupporting.value, 'alpha');
    expect(home.addressTooltip.value, isNull);
  });

  test('start refreshes now and when a network is saved', () async {
    final infos = <String, Object?>{'alpha': _info()};
    final home = controller(backend: FakeBackend(collected: () => infos));

    home.start();
    await pumpEventQueue();

    expect(home.savedCount.value, 2);
    expect(home.runningCount.value, 1);
    expect(home.serviceVersion.value, 1);

    infos['gamma'] = _info();
    await saved.addNetwork('n3', Network()..networkName = 'gamma');
    await pumpEventQueue();

    expect(home.savedCount.value, 3);
    expect(home.runningCount.value, 2);
  });

  test('disposing during a NAT probe writes no disposed signal', () async {
    final gate = Completer<NatProbe>();
    final home = controller(
      backend: FakeBackend(collected: () => const {}),
      probe: () => gate.future,
    );

    final detection = home.detectNat();
    expect(home.probing.value, isTrue);
    home.dispose();
    gate.complete(
      const NatProbe(publicAddress: '203.0.113.7', natType: NatType.fullCone),
    );

    await expectLater(detection, completes);
    expect(
      home.probing.peek(),
      isTrue,
      reason: 'the probe result and the flag are not written after dispose',
    );
  });

  test('disposing during the version probe writes no disposed signal', () async {
    final gate = Completer<int?>();
    final home = controller(
      backend: FakeBackend(collected: () => const {}),
      service: () => gate.future,
    );

    final check = home.checkServiceVersion();
    home.dispose();
    gate.complete(7);

    await expectLater(check, completes);
    expect(home.serviceVersion.peek(), isNull);
  });

  test('dispose releases every signal it created', () async {
    final home = controller(
      backend: FakeBackend(collected: () => {'alpha': _info()}),
    );

    await home.refresh();
    await home.detectNat();
    await home.checkServiceVersion();
    // Every primitive the page reads.
    home.status.value;
    home.backendKind.value;
    home.serviceVersion.value;
    home.showSettings.value;
    home.easyTierVersion.value;
    home.refreshed.value;
    home.savedCount.value;
    home.runningCount.value;
    home.runningNames.value;
    home.runningNamesMultiline.value;
    home.addressKind.value;
    home.address.value;
    home.addressSupporting.value;
    home.addressMoreCount.value;
    home.addressTooltip.value;
    home.natType.value;
    home.natReportedByEasytier.value;
    home.probing.value;
    home.receiveRate.value;
    home.sendRate.value;
    home.totalReceived.value;
    home.totalSent.value;
    home.trafficIdle.value;

    home.dispose();

    expect(home.refreshed.disposed, isTrue);
    expect(home.serviceVersion.disposed, isTrue);
    expect(home.probing.disposed, isTrue);
    expect(home.receiveRate.disposed, isTrue);
    expect(home.sendRate.disposed, isTrue);
    expect(home.totalReceived.disposed, isTrue);
    expect(home.totalSent.disposed, isTrue);
    expect(home.status.disposed, isTrue);
    expect(home.backendKind.disposed, isTrue);
    expect(home.showSettings.disposed, isTrue);
    expect(home.easyTierVersion.disposed, isTrue);
    expect(home.savedCount.disposed, isTrue);
    expect(home.runningCount.disposed, isTrue);
    expect(home.runningNames.disposed, isTrue);
    expect(home.runningNamesMultiline.disposed, isTrue);
    expect(home.addressKind.disposed, isTrue);
    expect(home.address.disposed, isTrue);
    expect(home.addressSupporting.disposed, isTrue);
    expect(home.addressMoreCount.disposed, isTrue);
    expect(home.addressTooltip.disposed, isTrue);
    expect(home.natType.disposed, isTrue);
    expect(home.natReportedByEasytier.disposed, isTrue);
    expect(home.trafficIdle.disposed, isTrue);
  });
}

/// EasyTier information for one running instance.
Map<String, Object?> _info({
  String hostname = 'alpha',
  String version = '2.7.0-1649ec00',
  String natType = 'Unknown',
  String virtualIpv4 = '10.144.0.2',
  List<Map<String, Object?>> peers = const [],
}) => {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': hostname,
    'version': version,
    'virtual_ipv4': {
      'address': {'addr': _ipv4(virtualIpv4)},
    },
    'stun_info': {'udp_nat_type': natType},
  },
  'peer_route_pairs': peers,
};

Map<String, Object?> _peer({required int rx, required int tx}) => {
  'route': {
    'peer_id': '2',
    'hostname': 'peer-one',
    'ipv4_addr': {
      'address': {'addr': _ipv4('10.144.0.9')},
    },
  },
  'peer': {
    'conns': [
      {
        'stats': {'rx_bytes': '$rx', 'tx_bytes': '$tx'},
      },
    ],
  },
};

int _ipv4(String address) =>
    address.split('.').fold(0, (value, part) => (value << 8) | int.parse(part));

/// A backend that answers one queued collection per refresh.
class _ScriptedBackend extends FakeBackend {
  _ScriptedBackend(this.answers);

  final List<Future<Map<String, Instance>> Function()> answers;
  int calls = 0;

  @override
  Future<Map<String, Instance>> collect(Map<String, Network> networks) {
    final answer = answers[calls++];
    return answer();
  }
}

/// A collected instance map whose measuring step throws.
class _ExplodingInstances extends MapBase<String, Instance> {
  final _entries = <String, Instance>{};

  @override
  Iterable<Instance> get values => throw StateError('measuring failed');

  @override
  Instance? operator [](Object? key) => _entries[key];

  @override
  void operator []=(String key, Instance value) => _entries[key] = value;

  @override
  void clear() => _entries.clear();

  @override
  Iterable<String> get keys => _entries.keys;

  @override
  Instance? remove(Object? key) => _entries.remove(key);
}

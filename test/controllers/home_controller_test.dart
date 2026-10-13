import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/utils/stun_probe.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  late Map<String, Object?> info;
  late HomeController controller;

  Map<String, Object?> stats() {
    final pair =
        (info['peer_route_pairs'] as List<Object?>).single
            as Map<String, Object?>;
    final conn =
        ((pair['peer'] as Map<String, Object?>)['conns'] as List<Object?>)
                .single
            as Map<String, Object?>;
    return conn['stats'] as Map<String, Object?>;
  }

  setUp(() async {
    await seedNetworks();
    info = jsonDecode(
      File('test/fixtures/collected_instance.json').readAsStringSync(),
    ) as Map<String, Object?>;
    controller = HomeController(
      backend: FakeBackend(collected: () => {'alpha': info}),
      probe: () async => const NatProbe(
        publicAddress: '203.0.113.7',
        natType: NatType.fullCone,
      ),
      probeServiceVersion: () async => null,
    );
    addTearDown(controller.dispose);
  });

  test('reads the running networks from the backend', () async {
    await controller.refresh();

    expect(controller.instances.value.keys, ['n1']);
    expect(controller.easyTierVersion.value, '2.7.0-1649ec00');
    expect(controller.virtualAddresses.value, [
      (network: 'alpha', address: '10.144.0.2', host: null),
    ]);
  });

  test('names this device as Magic DNS does, where enabled', () async {
    await saved.updateNetwork(
      'n1',
      Network()
        ..networkName = 'alpha'
        ..flags.acceptDns = true,
    );
    await controller.refresh();

    expect(controller.virtualAddresses.value.single.host, 'host-b.et.net');
  });

  test('prefers the NAT type EasyTier reports over the probe', () async {
    await controller.detectNat();
    expect(controller.nat.value, (type: NatType.fullCone, reported: false));

    await controller.refresh();
    expect(controller.nat.value, (type: NatType.symmetric, reported: true));
  });

  test('measures traffic between refreshes', () async {
    await controller.refresh();
    expect(controller.traffic.value?.received, 1848);
    expect(controller.traffic.value?.receiveRate, 0);

    stats()['rx_bytes'] = '${1848 + 4096}';
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await controller.refresh();
    expect(controller.traffic.value?.received, 1848 + 4096);
    expect(controller.traffic.value!.receiveRate, greaterThan(0));
    expect(controller.traffic.value!.sendRate, 0);
  });

  test('marks the first refresh, whether or not it succeeds', () async {
    expect(controller.refreshed.value, isFalse);

    await controller.refresh();
    expect(controller.refreshed.value, isTrue);
  });
}

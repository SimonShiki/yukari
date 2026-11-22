import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari/signals/instances.dart' as running;
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/signals/udp_broadcast_relay.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/udp_broadcast_interfaces.dart';
import 'package:yukari_core/system/udp_broadcast_relay.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

Network _network({bool noTun = false}) => Network()
  ..networkName = 'alpha'
  ..flags.enableUdpBroadcastRelay = true
  ..flags.noTun = noTun;

LinuxIpv4Interface _tun(int address, {String name = 'et_a', int index = 8}) =>
    LinuxIpv4Interface(name, index, address, 20, 1, true, 1400);

void main() {
  test('waits for DHCP and uses the prefix of the assigned TUN', () async {
    final snapshots = <List<RelayRegistration>>[];
    var reads = 0;
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      attempts: 3,
      retryDelay: Duration.zero,
      assignedAddress: (_) async => ++reads == 3 ? '10.2.3.4/24' : null,
      interfaces: () => [_tun(0x0a020304)],
      configure: (targets) async => snapshots.add(targets),
    );
    addTearDown(auto.stopAll);

    expect(
      await auto.start('a', _network()..flags.deviceName = 'et_a'),
      'et_a',
    );
    expect(reads, 3);
    final target = snapshots.single.single.target;
    expect(target.tunIfindex, 8);
    expect(target.virtualIpv4, 0x0a020304);
    expect(target.virtualBroadcast, 0x0a020fff);
  });

  test('stops waiting after the configured number of attempts', () async {
    var reads = 0;
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      attempts: 2,
      retryDelay: Duration.zero,
      log: (_) {},
      interfaces: () {
        reads++;
        return [];
      },
      configure: (_) async => fail('No TUN was found'),
    );
    expect(await auto.start('a', _network()..ipv4 = '10.2.3.4'), isNull);
    expect(reads, 2);
  });

  test('keeps independent relay targets until each network stops', () async {
    final snapshots = <List<RelayRegistration>>[];
    final first = _tun(0x0a020304);
    final second = _tun(0x0a030405, name: 'et_b', index: 9);
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      interfaces: () => [first, second],
      configure: (targets) async => snapshots.add(targets),
    );
    await auto.start('a', _network()..ipv4 = '10.2.3.4');
    await auto.start('b', _network()..ipv4 = '10.3.4.5');
    expect(snapshots.last.map((item) => item.target.networkId), ['a', 'b']);
    await auto.stop('a');
    expect(snapshots.last.single.target.networkId, 'b');
    await auto.stopAll();
    expect(snapshots.last, isEmpty);
  });

  test('re-resolves and republishes a target on every start', () async {
    final snapshots = <List<RelayRegistration>>[];
    var tun = _tun(0x0a020304);
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      interfaces: () => [tun],
      configure: (targets) async => snapshots.add(targets),
    );
    addTearDown(auto.stopAll);

    expect(await auto.start('a', _network()..ipv4 = '10.2.3.4'), 'et_a');
    tun = _tun(0x0a020305);
    expect(await auto.start('a', _network()..ipv4 = '10.2.3.5'), 'et_a');

    expect(snapshots, hasLength(2));
    expect(snapshots.last.single.target.virtualIpv4, 0x0a020305);
  });

  test('an ineligible restart removes its previously active target', () async {
    final snapshots = <List<RelayRegistration>>[];
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      interfaces: () => [_tun(0x0a020304)],
      configure: (targets) async => snapshots.add(targets),
    );
    addTearDown(auto.stopAll);

    await auto.start('a', _network()..ipv4 = '10.2.3.4');
    expect(await auto.start('a', _network(noTun: true)), isNull);
    expect(snapshots.last, isEmpty);
  });

  test(
    'DHCP does not fall back to the saved IPv4 while assignment is pending',
    () async {
      final auto = UdpBroadcastRelayAuto(
        available: () => true,
        attempts: 1,
        log: (_) {},
        assignedAddress: (_) async => null,
        interfaces: () => [_tun(0x0a020304)],
        configure: (_) async => fail('Pending DHCP must not match the old IP'),
      );
      final network = _network()
        ..dhcp = true
        ..ipv4 = '10.2.3.4';

      expect(await auto.start('a', network), isNull);
    },
  );

  testWidgets('stop during retry avoids another assigned-address read', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final scanned = Completer<void>();
      var reads = 0;
      final auto = UdpBroadcastRelayAuto(
        available: () => true,
        attempts: 3,
        retryDelay: const Duration(milliseconds: 30),
        assignedAddress: (_) async {
          reads++;
          return null;
        },
        interfaces: () {
          if (!scanned.isCompleted) scanned.complete();
          return [];
        },
        log: (_) {},
      );

      final network = _network()
        ..dhcp = false
        ..ipv4 = '10.2.3.4';
      final start = auto.start('a', network);
      await scanned.future;
      await auto.stop('a');

      expect(await start, isNull);
      expect(reads, 1);
    });
  });

  test(
    'a pending start cannot register a target after stop and restart',
    () async {
      final gate = Completer<String?>();
      var reads = 0;
      final snapshots = <List<RelayRegistration>>[];
      final auto = UdpBroadcastRelayAuto(
        available: () => true,
        interfaces: () => [_tun(0x0a020304)],
        configure: (targets) async => snapshots.add(targets),
        assignedAddress: (_) =>
            ++reads == 1 ? gate.future : Future.value('10.2.3.4'),
      );
      addTearDown(auto.stopAll);
      final stale = auto.start('a', _network());
      await auto.stop('a');
      expect(await auto.start('a', _network()), 'et_a');
      gate.complete('10.2.3.4');
      expect(await stale, isNull);
      expect(snapshots, hasLength(1));
    },
  );

  test('skips unavailable platforms, missing CAP_NET_RAW and No-TUN', () async {
    final network = _network();
    for (final (available, candidate) in [
      (false, network),
      (true, _network(noTun: true)),
    ]) {
      final auto = UdpBroadcastRelayAuto(
        available: () => available,
        interfaces: () => fail('Ineligible relay enumerated interfaces'),
      );
      expect(auto.appliesTo(candidate), isFalse);
      expect(await auto.start('a', candidate), isNull);
    }
  });

  test('recognizes TUNs when sysfs tun flags are unavailable', () {
    final fallback = LinuxIpv4Interface(
      'et_a',
      8,
      0x0a020304,
      24,
      0x11,
      false,
      1400,
    );
    expect(fallback.isTunnel, isTrue);
    expect(
      findRelayTun([fallback], name: '', address: fallback.ipv4),
      same(fallback),
    );
    expect(fallback.physical, isNull);
  });

  test('accepts bridged LAN interfaces without filtering their names', () {
    final bridge = LinuxIpv4Interface(
      'br-lan',
      4,
      0xc0a80101,
      24,
      0x43,
      false,
      1500,
    );
    expect(bridge.physical?.name, 'br-lan');
  });

  test('only resolves unique, up L3 tunnels using the assigned address', () {
    final tun = _tun(0x0a020304);
    final physical = LinuxIpv4Interface(
      'wlan0',
      2,
      tun.ipv4,
      24,
      1,
      false,
      1500,
    );
    expect(findRelayTun([physical], name: 'wlan0', address: tun.ipv4), isNull);
    expect(
      findRelayTun([tun, physical], name: '', address: tun.ipv4),
      same(tun),
    );
    expect(
      findRelayTun(
        [tun, _tun(tun.ipv4, name: 'another_tun', index: 10)],
        name: '',
        address: tun.ipv4,
      ),
      isNull,
    );
  });

  test(
    'a DHCP renewal stays on the known TUN when another uses its old IP',
    () {
      final original = _tun(0x0a020304);
      final current = _tun(0x0a020309);
      final other = _tun(original.ipv4, name: 'other', index: 9);
      final target = relayTarget('a', original);
      final updated = resolveRelayTargets(
        [current, other],
        [(target: target, followsDhcp: true)],
        {'a': (target: target, mtu: original.mtu)},
      );
      expect(updated['a']!.target.virtualIpv4, current.ipv4);
      expect(updated['a']!.target.tunIfindex, current.index);
    },
  );

  test('a DHCP renewal keeps its TUN after a scan missed the old address', () {
    final original = _tun(0x0a020304);
    final current = _tun(0x0a020309);
    final target = relayTarget('a', original);
    final updated = resolveRelayTargets(
      [current],
      [(target: target, followsDhcp: true)],
      {},
    );

    expect(updated['a']!.target.virtualIpv4, current.ipv4);
    expect(updated['a']!.target.tunIfindex, current.index);
  });

  test('skips TUNs configured in a separate network namespace', () async {
    final auto = UdpBroadcastRelayAuto(
      available: () => true,
      interfaces: () => fail('Relay attempted host interface lookup'),
    );
    final network = _network()..netNamespace = 'private';
    expect(await auto.start('a', network), isNull);
  });

  test(
    'app starts once, releases on service mode, and follows removal',
    () async {
      await seedWith({'a': _network()});
      final kind = signal(BackendKind.service);
      final setup = _Setup();
      final auto = AppUdpBroadcastRelayAuto(setup: setup, backendKind: kind);
      addTearDown(auto.dispose);
      await running.refreshInstances(
        FakeBackend(
          collected: () => {
            'alpha': {'running': true},
          },
        ),
      );
      expect(setup.started, isEmpty);

      kind.value = BackendKind.ffi;
      await pumpEventQueue();
      expect(setup.started, ['a']);
      kind.value = BackendKind.service;
      await pumpEventQueue();
      expect(setup.stopped, ['a']);
      kind.value = BackendKind.ffi;
      await pumpEventQueue();
      expect(setup.started, ['a', 'a']);

      running.forgetInstances(['a']);
      await pumpEventQueue();
      expect(setup.stopped, ['a', 'a']);
    },
  );

  test('app relay stops when a running network becomes No-TUN', () async {
    await seedWith({'a': _network()});
    final setup = _Setup();
    final auto = AppUdpBroadcastRelayAuto(
      setup: setup,
      backendKind: signal(BackendKind.ffi),
    );
    addTearDown(auto.dispose);
    final backend = FakeBackend(
      collected: () => {
        'alpha': {'running': true},
      },
    );

    await running.refreshInstances(backend);
    expect(setup.started, ['a']);
    final updated = saved.networks.peek()['a']!.copy()..flags.noTun = true;
    await saved.updateNetwork('a', updated);
    await running.refreshInstances(backend);
    await pumpEventQueue();

    expect(setup.stopped, ['a']);
  });

  test('initializer disposes the prior app-mode relay observer', () async {
    if (!Platform.isLinux) return;
    final firstSetup = _Setup();
    final kind = signal(BackendKind.service);
    final first = initUdpBroadcastRelayAuto(
      setup: firstSetup,
      backendKind: kind,
    );
    final second = initUdpBroadcastRelayAuto(
      setup: _Setup(),
      backendKind: kind,
    );
    addTearDown(() async {
      await second?.dispose();
    });

    expect(first, isNotNull);
    expect(second, isNotNull);
    await pumpEventQueue();
    expect(firstSetup.stopAllCalls, 1);
  });
}

final class _Setup implements UdpBroadcastRelaySetup {
  final started = <String>[];
  final stopped = <String>[];
  var stopAllCalls = 0;

  @override
  bool appliesTo(Network network) =>
      network.flags.enableUdpBroadcastRelay && !network.flags.noTun;

  @override
  Future<String?> start(String networkId, Network network) async {
    started.add(networkId);
    return 'et_$networkId';
  }

  @override
  Future<void> stop(String networkId) async => stopped.add(networkId);

  @override
  Future<void> stopAll() async {
    stopAllCalls++;
  }
}

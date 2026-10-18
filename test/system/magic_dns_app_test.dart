import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/instances.dart' as running;
import 'package:yukari/signals/magic_dns.dart';
import 'package:yukari_core/system/magic_dns_auto.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

const _info = <String, Object?>{
  'running': true,
  'my_node_info': <String, Object?>{
    'peer_id': 1,
    'hostname': 'laptop',
    'virtual_ipv4': '10.144.0.2/24',
  },
  'peer_route_pairs': <Object?>[],
  'events': <Object?>[],
};

Network _network(String name, {bool acceptDns = true, bool noTun = false}) =>
    Network()
      ..networkName = name
      ..flags = (NetworkFlags()
        ..acceptDns = acceptDns
        ..noTun = noTun);

/// Records what the app effect asked the setup to do.
final class _FakeSetup implements MagicDnsSetup {
  final started = <String>[];

  @override
  bool appliesTo(Network network) =>
      network.flags.acceptDns && !network.flags.noTun;

  @override
  Future<String?> start(String networkId, Network network) async {
    started.add(networkId);
    return 'et_$networkId';
  }

  @override
  Future<void> revert(String networkId) async {}

  @override
  Future<void> revertAll() async {}
}

void main() {
  test('sets DNS up once per app-mode network start', () async {
    await seedWith({
      'n1': _network('alpha'),
      'n2': _network('beta', acceptDns: false),
      'n3': _network('gamma', noTun: true),
    });
    Map<String, Object?> infos() => {
      'alpha': _info,
      'beta': _info,
      'gamma': _info,
    };
    await running.refreshInstances(FakeBackend(collected: infos));
    final setup = _FakeSetup();
    final auto = AppMagicDnsAuto(setup: setup);
    addTearDown(auto.dispose);

    await pumpEventQueue();

    expect(setup.started, ['n1']);

    // A later collection of the same running instance asks for nothing again.
    await running.refreshInstances(FakeBackend(collected: infos));
    await pumpEventQueue();
    expect(setup.started, ['n1']);

    // Closing the card is remembered, and a stop offers it again.
    dismissMagicDnsCard('n1');
    expect(magicDnsDismissedCards.value, contains('n1'));

    // Stopping the network, and starting it again, is a new start.
    await running.refreshInstances(
      FakeBackend(collected: () => {'beta': _info, 'gamma': _info}),
    );
    await pumpEventQueue();
    expect(magicDnsDismissedCards.value, isEmpty);
    await running.refreshInstances(FakeBackend(collected: infos));
    await pumpEventQueue();
    expect(setup.started, ['n1', 'n1']);
  });

  test('a failing setup never reaches the network', () async {
    await seedWith({'n1': _network('alpha')});
    await running.refreshInstances(
      FakeBackend(collected: () => {'alpha': _info}),
    );
    final auto = AppMagicDnsAuto(setup: _ThrowingSetup());
    addTearDown(auto.dispose);

    await pumpEventQueue();

    // The effect swallowed the error; nothing else to observe but the page's
    // own state, which stays intact.
    expect(running.instances.value.keys, ['n1']);
  });

  test(
    'stands down in service mode, and re-arms when it is app mode again',
    () async {
      await seedWith({'n1': _network('alpha')});
      await running.refreshInstances(
        FakeBackend(collected: () => {'alpha': _info}),
      );
      final kind = signal(BackendKind.service);
      final setup = _FakeSetup();
      final auto = AppMagicDnsAuto(setup: setup, backendKind: kind);
      addTearDown(auto.dispose);

      await pumpEventQueue();
      expect(setup.started, isEmpty, reason: 'the daemon configures its own');

      kind.value = BackendKind.ffi;
      await pumpEventQueue();
      expect(setup.started, ['n1']);
    },
  );

  test('restores a closed card in service mode too', () async {
    await seedWith({'n1': _network('alpha')});
    await running.refreshInstances(
      FakeBackend(collected: () => {'alpha': _info}),
    );
    final kind = signal(BackendKind.service);
    final auto = AppMagicDnsAuto(setup: _FakeSetup(), backendKind: kind);
    addTearDown(auto.dispose);
    await pumpEventQueue();

    dismissMagicDnsCard('n1');
    expect(magicDnsDismissedCards.value, contains('n1'));

    // The daemon owns the instance, but the app still offers the card again
    // once that network is no longer running.
    await running.refreshInstances(FakeBackend(collected: () => {}));
    await pumpEventQueue();
    expect(magicDnsDismissedCards.value, isEmpty);
  });

  test('dismissed cards are session state that a stop restores', () {
    resetMagicDnsDismissedCards();
    addTearDown(resetMagicDnsDismissedCards);

    dismissMagicDnsCard('n1');
    expect(magicDnsDismissedCards.value, {'n1'});

    restoreMagicDnsCard('n1');
    expect(magicDnsDismissedCards.value, isEmpty);
  });
}

final class _ThrowingSetup extends _FakeSetup {
  @override
  Future<String?> start(String networkId, Network network) async {
    throw StateError('boom');
  }
}

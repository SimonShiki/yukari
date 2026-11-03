import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari_core/models/peer.dart';
import 'package:yukari/signals/instances.dart';
import 'package:yukari/utils/stun_probe.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  setUp(seedNetworks);

  test('concurrent refreshes cause exactly one collection', () async {
    final backend = CountingBackend(collected: () => {'alpha': _info});

    final before = backend.collects;
    await Future.wait([
      refreshInstances(backend),
      refreshInstances(backend),
      refreshInstances(backend),
    ]);

    expect(backend.collects - before, 1);
    expect(instances.value.keys, ['n1']);
    expect(instancesLoaded.value, isTrue);
  });

  test('one backend never waits behind another', () async {
    final gate = Completer<void>();
    final slow = _GatedBackend(gate);

    final started = refreshInstances(slow);
    // The second backend collects on its own rather than sharing the first
    // one's answer.
    await refreshInstances(FakeBackend(collected: () => {'alpha': _info}));

    expect(instances.value.keys, ['n1']);
    gate.complete();
    await started;
  });

  test('each awaited refresh collects again', () async {
    final backend = CountingBackend(collected: () => {'alpha': _info});

    await refreshInstances(backend);
    await refreshInstances(backend);

    expect(backend.collects, 2);
  });

  test('awaiting an in-flight refresh waits for it', () async {
    final gate = Completer<void>();
    final backend = _GatedBackend(gate);

    final inFlight = refreshInstances(backend);
    var settled = false;
    final waiting = inFlight.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);

    expect(settled, isFalse, reason: 'the collection is still running');
    gate.complete();
    await waiting;

    expect(settled, isTrue);
    expect(instances.value.keys, ['n1']);
  });

  test('a failed collection keeps the last state and releases the guard', () async {
    await refreshInstances(
      FakeBackend(collected: () => {'alpha': _info}),
    );
    final failing = CountingBackend(failCollect: true);

    await expectLater(refreshInstances(failing), throwsException);
    expect(instances.value.keys, ['n1'], reason: 'the last state stands');
    expect(instancesLoaded.value, isTrue);

    // The failure must not leave the in-flight guard set.
    await expectLater(refreshInstances(failing), throwsException);
    expect(failing.collects, 2);
  });

  test('forgetInstances drops only the ids it is given', () async {
    await refreshInstances(
      FakeBackend(
        collected: () => {'alpha': _info, 'beta': {'running': true}},
      ),
    );
    expect(instances.value.keys, unorderedEquals(['n1', 'n2']));

    forgetInstances(['n1']);

    expect(instances.value.keys, ['n2']);
    expect(instancesLoaded.value, isTrue);
  });

  test('a refresh updates the dashboard and the list together', () async {
    var running = <String, Object?>{'alpha': _info};
    final backend = FakeBackend(collected: () => running);
    final home = HomeController(
      backend: backend,
      probe: () async =>
          const NatProbe(publicAddress: null, natType: NatType.unknown),
      probeServiceVersion: () async => null,
    );
    addTearDown(home.dispose);
    final list = NetworkPageController(
      navigate: (_, _) {},
      showMessage: (_) {},
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: backend,
    );
    addTearDown(list.dispose);

    // One controller's refresh is enough: both read the same store.
    await home.refresh();

    expect(home.runningCount.value, 1);
    expect(list.instances.value.keys, ['n1']);
    expect(list.cards.value.first.running, isTrue);

    // And the list's next refresh moves the dashboard too.
    running = {};
    await list.refresh();

    expect(list.instances.value, isEmpty);
    expect(home.runningCount.value, 0);
  });

  test('a reset drops a collection that outlives it', () async {
    final gate = Completer<void>();
    final backend = _GatedBackend(gate);

    final stale = refreshInstances(backend);
    initInstances();
    gate.complete();
    await stale;

    expect(instances.value, isEmpty);
    expect(instancesLoaded.value, isFalse);
  });
}

/// EasyTier information of one running instance.
const _info = {'running': true};

/// A backend whose collection waits for the test to release it.
class _GatedBackend extends FakeBackend {
  _GatedBackend(this.gate) : super(collected: () => {'alpha': _info});

  final Completer<void> gate;

  @override
  Future<Map<String, String>> collectInfos() async {
    await gate.future;
    return super.collectInfos();
  }
}

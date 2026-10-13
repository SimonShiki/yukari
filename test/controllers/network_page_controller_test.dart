import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/models/models.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  late FakeBackend backend;
  late NetworkPageController controller;
  late List<String> messages;
  late List<Network> warned;

  setUp(() async {
    await seedNetworks();
    backend = FakeBackend(maxInstances: 1);
    messages = [];
    warned = [];
    controller = NetworkPageController(
      navigate: (_, _) {},
      showMessage: messages.add,
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (network) async => warned.add(network),
      backend: backend,
    );
    addTearDown(controller.dispose);
    controller.setActive(true);
    await controller.refresh();
  });

  test('starts and stops networks through the backend', () async {
    await controller.toggle('n1', true);
    expect(backend.started.keys, ['n1']);
    expect(controller.instances.value.keys, ['n1']);
    expect(controller.transitions.value, isEmpty);

    await controller.toggle('n1', false);
    expect(backend.stopped, ['alpha']);
    expect(controller.instances.value, isEmpty);
  });

  test('respects the backend instance limit', () async {
    await controller.toggle('n1', true);
    await controller.toggle('n2', true);
    expect(backend.started.keys, ['n1']);
    expect(messages, ['Only one network can run at a time.']);
  });

  test('explains missing privileges instead of starting', () async {
    backend.access = TunAccess.elevationRequired;
    await controller.toggle('n1', true);
    expect(backend.started, isEmpty);
    expect(warned.single.networkName, 'alpha');
  });

  test('marks networks that fail to start', () async {
    backend.startError = StateError('no TUN');
    await controller.toggle('n1', true);
    expect(controller.transitions.value['n1'], InstanceStatus.failed);
    expect(messages.single, contains('no TUN'));
  });
}

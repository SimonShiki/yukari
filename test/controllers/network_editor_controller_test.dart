import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/signals/networks.dart';

import '../networks_fixture.dart';

void main() {
  setUp(seedNetworks);

  NetworkEditorController editor(String id) =>
      NetworkEditorController(id: id, showMessage: (_) {});

  test('update applies and saves the change immediately', () async {
    final controller = editor('n1');
    await controller.update((n) => n.networkName = 'gamma');

    expect(controller.networkName.value, 'gamma');
    expect(networks.value['n1']!.networkName, 'gamma');
    expect((await persisted('n1')).networkName, 'gamma');
    controller.dispose();
  });

  test('saved state is decoupled from the working copy', () async {
    final controller = editor('n1');
    await controller.update((n) => n.ipv4 = '10.0.0.1/24');
    controller.network.value!.ipv4 = 'garbage';

    expect(networks.value['n1']!.ipv4, '10.0.0.1/24');
    controller.dispose();
  });

  test('network name must not clash with another network', () {
    final controller = editor('n1');
    expect(controller.networkNameError('alpha'), isNull);
    expect(controller.networkNameError('beta'), isNotNull);
    expect(controller.networkNameError(''), isNotNull);
    controller.dispose();
  });

  test('missing network yields no working copy', () {
    final controller = editor('missing');
    expect(controller.network.value, isNull);
    controller.dispose();
  });
}

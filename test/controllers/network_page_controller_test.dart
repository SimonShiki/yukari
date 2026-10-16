import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/signals/instance_logs.dart';
import 'package:yukari/signals/networks.dart' as saved;

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  NetworkPageController build({
    required FakeBackend backend,
    required List<String> messages,
    List<String>? navigated,
    Future<bool> Function(Network)? confirmDelete,
    List<Network>? warnings,
    bool Function()? invalidInput,
    Future<bool> Function()? confirmDiscardDialog,
    Future<PickedConfig?> Function()? pickConfig,
    void Function(String)? validateConfig,
    Duration refreshInterval = const Duration(seconds: 10),
    bool Function()? isWide,
  }) => NetworkPageController(
    navigate: (route, id) => navigated?.add(id == null ? route : '$route:$id'),
    showMessage: messages.add,
    confirmDelete: confirmDelete ?? (_) async => true,
    showTunPermissionWarning: (network) async => warnings?.add(network),
    backend: backend,
    invalidInput: invalidInput,
    confirmDiscardDialog: confirmDiscardDialog,
    pickConfig: pickConfig,
    validateConfig: validateConfig,
    refreshInterval: refreshInterval,
    isWide: isWide,
  );

  test('refresh collects instances, and the cards start unknown', () async {
    await seedNetworks();
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    expect(
      controller.cards.value.map((card) => card.status),
      [InstanceStatus.unknown, InstanceStatus.unknown],
    );

    await controller.refresh();

    expect(controller.loaded.value, isTrue);
    expect(controller.refreshError.value, isNull);
    expect(controller.cards.value.map((card) => card.running), [false, false]);
    expect(
      controller.cards.value.map((card) => card.status),
      [InstanceStatus.stopped, InstanceStatus.stopped],
    );
    expect(controller.cards.value.map((card) => card.name), ['alpha', 'beta']);
  });

  test('starts and stops through the backend', () async {
    await seedNetworks();
    final backend = FakeBackend();
    final controller = build(backend: backend, messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(backend.started.keys, ['n1']);
    await controller.refresh();
    expect(controller.instances.value.keys, ['n1']);
    expect(controller.cards.value.first.status, InstanceStatus.running);
    expect(controller.cards.value.first.onToggle, isNotNull);
    expect(controller.selectionRunning.value, isTrue);

    await controller.toggle('n1', false);
    await controller.refresh();

    expect(backend.stopped, ['alpha']);
    expect(controller.instances.value, isEmpty);
  });

  test('records the instance events while refreshing', () async {
    await seedNetworks();
    final backend = FakeBackend(
      collected: () => {
        'alpha': {
          'running': true,
          'events': ['{"time":"2024-01-01T00:00:00Z","event":"TunDeviceReady"}'],
        },
      },
    );
    final controller = build(backend: backend, messages: <String>[]);
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(instanceLogs('n1').value.single.kind, 'TunDeviceReady');
  });

  test('the instance limit refuses another network', () async {
    await seedNetworks();
    final backend = FakeBackend(maxInstances: 1);
    final messages = <String>[];
    final controller = build(backend: backend, messages: messages);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.toggle('n1', true);
    await controller.refresh();

    expect(controller.cards.value.first.onToggle, isNull);
    await controller.toggle('n2', true);

    expect(messages, [strings.controllerOneNetwork]);
    expect(backend.started.keys, ['n1']);
  });

  test('missing privileges are explained instead of starting', () async {
    await seedNetworks();
    final backend = FakeBackend()..access = TunAccess.elevationRequired;
    final messages = <String>[];
    final warnings = <Network>[];
    final controller = build(
      backend: backend,
      messages: messages,
      warnings: warnings,
    );
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(warnings.map((network) => network.networkName), ['alpha']);
    expect(backend.started, isEmpty);
    expect(controller.transitions.value, isEmpty);
    expect(messages, isEmpty);
  });

  test('a denied TUN request starts nothing and says nothing', () async {
    await seedNetworks();
    final backend = FakeBackend()..access = TunAccess.denied;
    final messages = <String>[];
    final controller = build(backend: backend, messages: messages);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(backend.started, isEmpty);
    expect(controller.transitions.value, isEmpty);
    expect(messages, isEmpty);
  });

  test('a failed start is marked and reported', () async {
    await seedNetworks();
    final backend = FakeBackend()..startError = StateError('no tun');
    final messages = <String>[];
    final controller = build(backend: backend, messages: messages);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(controller.transitions.value['n1'], NetworkTransition.failed);
    expect(controller.cards.value.first.status, InstanceStatus.failed);
    // A failed start can be retried.
    expect(controller.cards.value.first.onToggle, isNotNull);
  });

  test('a failed start can be retried, and its marker cleared', () async {
    await seedNetworks();
    final backend = _FlakyStartBackend();
    final controller = build(backend: backend, messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(backend.starts, 1);
    expect(controller.transitions.value['n1'], NetworkTransition.failed);
    // The retry stays available while the failure is on screen.
    expect(controller.cards.value.first.onToggle, isNotNull);

    await controller.toggle('n1', true);
    await controller.refresh();

    expect(backend.starts, 2);
    expect(controller.instances.value.keys, ['n1']);
    expect(controller.transitions.value.containsKey('n1'), isFalse);
    expect(controller.cards.value.first.status, InstanceStatus.running);
  });

  test('a failed refresh keeps the last state and reports it', () async {
    await seedNetworks();
    final controller = build(backend: _FailingBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(
      controller.refreshError.value,
      strings.controllerRefresh('Exception: boom'),
    );
    expect(controller.instances.value, isEmpty);
    expect(controller.cards.value.first.status, InstanceStatus.unknown);
    expect(controller.cards.value.first.onToggle, isNull);
  });

  test('delete confirms first, then stops and clears the network', () async {
    await seedNetworks();
    final backend = FakeBackend(collected: () => {'alpha': {'running': true}});
    final messages = <String>[];
    final refusing = build(
      backend: backend,
      messages: messages,
      confirmDelete: (_) async => false,
    );
    addTearDown(refusing.dispose);
    await refusing.refresh();

    await refusing.delete('n1');

    expect(saved.networks.value.keys, contains('n1'));
    expect(backend.stopped, isEmpty);
    expect(refusing.deleting.value, isEmpty);

    final deleting = build(
      backend: backend,
      messages: messages,
      confirmDelete: (_) async => true,
    );
    addTearDown(deleting.dispose);
    await deleting.refresh();
    await deleting.delete('n1');

    expect(saved.networks.value.keys, ['n2']);
    expect(backend.stopped, ['alpha']);
    expect(instanceLogs('n1').value, isEmpty);
    expect(deleting.instances.value, isEmpty);
    expect(messages, isEmpty);
  });

  test('a delete the store refuses keeps the network and is reported', () async {
    final messages = <String>[];
    await _seedWithFailingWrites();
    final controller = build(backend: FakeBackend(), messages: messages);
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.delete('n1');

    expect(saved.networks.value.keys, contains('n1'));
    expect(messages, [strings.controllerDeleteFailed('alpha')]);
  });

  test('reorder reports a store failure, and moves a network otherwise', () async {
    final messages = <String>[];
    await _seedWithFailingWrites();
    final failing = build(backend: FakeBackend(), messages: messages);
    addTearDown(failing.dispose);

    await failing.reorder(0, 2);

    expect(messages, [strings.controllerReorderFailed]);
    expect(saved.networks.value.keys.toList(), ['n1', 'n2']);

    await seedNetworks();
    final workingController = build(backend: FakeBackend(), messages: messages);
    addTearDown(workingController.dispose);
    await workingController.reorder(1, 0);

    expect(saved.networks.value.keys.toList(), ['n2', 'n1']);
  });

  test('selection asks exactly once before invalid input is discarded', () async {
    await seedNetworks();
    var asked = 0;
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      invalidInput: () => true,
      confirmDiscardDialog: () async {
        asked++;
        return false;
      },
    );
    controller.start();
    addTearDown(controller.dispose);
    expect(controller.selectedId.value, 'n1');

    expect(await controller.select('n2'), isFalse);
    expect(asked, 1);
    expect(controller.selectedId.value, 'n1');
  });

  test('a clean selection changes without asking', () async {
    await seedNetworks();
    var asked = 0;
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      invalidInput: () => false,
      confirmDiscardDialog: () async {
        asked++;
        return true;
      },
    );
    controller.start();
    addTearDown(controller.dispose);

    expect(await controller.select('n2'), isTrue);
    expect(controller.selectedId.value, 'n2');
    expect(asked, 0);
  });

  test('selection follows the saved networks', () async {
    await seedNetworks();
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    expect(controller.selectedId.value, 'n1');
    await saved.deleteNetwork('n1');
    expect(controller.selectedId.value, 'n2');
    await saved.deleteNetwork('n2');
    expect(controller.selectedId.value, isNull);
  });

  test('the wide pane never loses its selection', () async {
    await seedNetworks();
    var asked = 0;
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      isWide: () => true,
      invalidInput: () => true,
      confirmDiscardDialog: () async {
        asked++;
        return true;
      },
    );
    controller.start();
    addTearDown(controller.dispose);
    expect(controller.selectedId.value, 'n1');

    // A rebuilt list that re-emits "nothing selected" must not drop the pane
    // or ask about the editor it would leave.
    expect(await controller.select(null), isTrue);

    expect(controller.selectedId.value, 'n1');
    expect(asked, 0);
  });

  test('the wide pane is edited and logged in place', () async {
    await seedNetworks();
    final navigated = <String>[];
    final controller = build(
      backend: FakeBackend(collected: () => {'alpha': {'running': true}}),
      messages: <String>[],
      navigated: navigated,
      isWide: () => true,
    );
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.edit('n2');

    expect(controller.selectedId.value, 'n2');
    expect(navigated, isEmpty);

    await controller.log('n1');

    expect(controller.selectedId.value, 'n1');
    expect(controller.instanceTab.value, InstanceTab.logs);
    expect(navigated, isEmpty);
  });

  test('narrow windows navigate for edit and log', () async {
    await seedNetworks();
    final navigated = <String>[];
    final controller = build(
      backend: FakeBackend(collected: () => {'alpha': {'running': true}}),
      messages: <String>[],
      navigated: navigated,
      isWide: () => false,
    );
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.edit('n2');
    await controller.log('n1');

    expect(navigated, ['network-edit:n2', 'network-logs:n1']);
    expect(controller.selectedId.value, 'n1');
    expect(controller.instanceTab.value, InstanceTab.peers);
  });

  test('edit and log follow the running state', () async {
    await seedNetworks();
    final navigated = <String>[];
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      navigated: navigated,
    );
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    controller.log('n1');
    controller.edit('n1');
    controller.openDetail('n1');
    controller.createManually();
    expect(navigated, [
      'network-edit:n1',
      'network-edit:n1',
      '/networks/create',
    ]);

    navigated.clear();
    await controller.toggle('n1', true);
    await controller.refresh();
    controller.edit('n1');
    controller.log('n1');
    controller.openDetail('n1');
    expect(navigated, ['network-logs:n1', 'network-instance:n1']);
  });

  test('imports a picked config', () async {
    await seedNetworks();
    final messages = <String>[];
    final controller = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async => const PickedConfig(
        name: 'imported.toml',
        content: '[network_identity]\nnetwork_name = "imported"\n',
      ),
      validateConfig: (_) {},
    );
    addTearDown(controller.dispose);

    await controller.importFromFile();
    await saved.settled();

    expect(
      saved.networks.value.values.map((network) => network.networkName),
      contains('imported'),
    );
    expect(messages, isEmpty);
  });

  test('rejects a config EasyTier or the name rule refuses', () async {
    await seedNetworks();
    final messages = <String>[];
    const content = '[network_identity]\nnetwork_name = "alpha"\n';
    final rejected = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async => const PickedConfig(name: 'taken.toml', content: content),
      validateConfig: (_) {},
    );
    addTearDown(rejected.dispose);

    await rejected.importFromFile();

    expect(messages, [
      strings.controllerImportInvalid('taken.toml', strings.validationNetworkExists),
    ]);

    messages.clear();
    final invalid = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async => const PickedConfig(name: 'broken.toml', content: content),
      validateConfig: (_) => throw const FormatException('bad toml'),
    );
    addTearDown(invalid.dispose);

    await invalid.importFromFile();

    expect(messages.single, contains('broken.toml'));
    expect(messages.single, contains('FormatException: bad toml'));
  });

  test('an unreadable file, and a dismissed picker, say what happened', () async {
    await seedNetworks();
    final messages = <String>[];
    final unreadable = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async => throw const FileSystemException('gone'),
    );
    addTearDown(unreadable.dispose);
    await unreadable.importFromFile();
    expect(messages, [strings.controllerFileUnavailable]);

    messages.clear();
    final dismissed = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async => null,
    );
    addTearDown(dismissed.dispose);
    await dismissed.importFromFile();
    expect(messages, isEmpty);
  });

  test('the periodic refresh exists only while something runs', () async {
    await seedNetworks();
    final backend = _CountingBackend();
    final controller = build(
      backend: backend,
      messages: <String>[],
      refreshInterval: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.setActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    // Nothing runs, so the periodic refresh is not started at all.
    expect(backend.collects, 1);

    await controller.toggle('n1', true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(backend.collects, greaterThan(2));

    controller.setActive(false);
    final settled = backend.collects;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(backend.collects, settled);
    expect(controller.active, isFalse);
  });
}

/// Seeds `n1`/`n2` into a store whose writes fail from now on.
Future<void> _seedWithFailingWrites() async {
  final store = temporaryStore();
  await store.save({
    'n1': Network()..networkName = 'alpha',
    'n2': Network()..networkName = 'beta',
  });
  await saved.init(store);
  addTearDown(saved.dispose);
  // A directory where the store writes makes every save fail.
  store.file.deleteSync();
  Directory(store.file.path).createSync(recursive: true);
}

/// A backend whose first start fails and whose second succeeds.
class _FlakyStartBackend extends FakeBackend {
  int starts = 0;

  @override
  Future<void> start(String id, Network network) async {
    starts++;
    if (starts == 1) throw Exception('no tun');
    return super.start(id, network);
  }
}

/// A backend whose collection always fails.
class _FailingBackend extends FakeBackend {
  @override
  Future<Map<String, String>> collectInfos() async => throw Exception('boom');
}

/// A backend that counts how often it was asked to collect.
class _CountingBackend extends FakeBackend {
  int collects = 0;

  @override
  Future<Map<String, String>> collectInfos() async {
    collects++;
    return super.collectInfos();
  }
}

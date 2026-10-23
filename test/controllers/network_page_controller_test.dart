import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/share/share_bundle.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/instance_logs.dart';
import 'package:yukari/signals/instances.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari_core/utils/easytier_config_serializer.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  NetworkPageController build({
    required FakeBackend backend,
    required List<String> messages,
    List<String>? navigated,
    List<String>? pushed,
    Future<bool> Function(Network)? confirmDelete,
    List<Network>? warnings,
    bool Function()? invalidInput,
    Future<bool> Function()? confirmDiscardDialog,
    Future<PickedConfig?> Function()? pickConfig,
    Future<bool> Function(String, String)? saveExportFile,
    void Function(String)? validateConfig,
    Duration refreshInterval = const Duration(seconds: 10),
    bool Function()? isWide,
  }) => NetworkPageController(
    navigate: (route, id) => navigated?.add(id == null ? route : '$route:$id'),
    pushRoute: pushed?.add,
    showMessage: messages.add,
    confirmDelete: confirmDelete ?? (_) async => true,
    showTunPermissionWarning: (network) async => warnings?.add(network),
    backend: backend,
    invalidInput: invalidInput,
    confirmDiscardDialog: confirmDiscardDialog,
    pickConfig: pickConfig,
    saveExportFile: saveExportFile,
    validateConfig: validateConfig,
    refreshInterval: refreshInterval,
    isWide: isWide,
  );

  test('refresh collects instances, and the cards start unknown', () async {
    await seedNetworks();
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    expect(controller.cards.value.map((card) => card.status), [
      InstanceStatus.unknown,
      InstanceStatus.unknown,
    ]);

    await controller.refresh();

    expect(controller.loaded.value, isTrue);
    expect(controller.refreshError.value, isNull);
    expect(controller.cards.value.map((card) => card.running), [false, false]);
    expect(controller.cards.value.map((card) => card.status), [
      InstanceStatus.stopped,
      InstanceStatus.stopped,
    ]);
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

  test('a card shares its network over QR above the shell', () async {
    await seedNetworks();
    final pushed = <String>[];
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      pushed: pushed,
    );
    controller.start();
    addTearDown(controller.dispose);

    controller.cards.value.first.onShare();
    controller.receiveByQr();

    expect(pushed, [shareSendPath(ShareKind.network, 'n1'), shareReceivePath]);
  });

  test(
    'the share actions fall back to navigating without a push route',
    () async {
      await seedNetworks();
      final navigated = <String>[];
      final controller = build(
        backend: FakeBackend(),
        messages: <String>[],
        navigated: navigated,
      );
      controller.start();
      addTearDown(controller.dispose);

      controller.cards.value.first.onShare();
      controller.receiveByQr();

      expect(navigated, [
        shareSendPath(ShareKind.network, 'n1'),
        shareReceivePath,
      ]);
    },
  );

  /// A saved network with one peer, so the sender can share it.
  Network shareable(String name) => Network()
    ..networkName = name
    ..nodes = [
      Node(
        id: 'peer',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
    ];

  test('nothing can be selected while no network exists', () async {
    await seedWith({});
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    expect(controller.canSelect, isFalse);
  });

  test('the selection counts, toggles and selects everything', () async {
    await seedNetworks();
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);
    final selection = controller.selection;

    expect(controller.canSelect, isTrue);
    expect(selection.selecting.value, isFalse);

    selection.enter();
    expect(selection.selecting.value, isTrue);
    // Selection always starts empty.
    expect(selection.orderedSelection, isEmpty);

    selection.toggle('n2');
    selection.toggle('n1');
    expect(selection.count.value, 2);
    // Ordered as the list shows them, not as they were tapped.
    expect(selection.orderedSelection, ['n1', 'n2']);
    expect(selection.allSelected.value, isTrue);

    selection.toggle('n1');
    expect(selection.count.value, 1);
    expect(selection.allSelected.value, isFalse);

    selection.toggleAll();
    expect(selection.count.value, 2);
    selection.toggleAll();
    expect(selection.ids.value, isEmpty);

    selection.exit();
    expect(selection.selecting.value, isFalse);
  });

  test('a selection shares as one bundle path and leaves selection', () async {
    await seedWith({'n1': shareable('alpha'), 'n2': shareable('beta')});
    final controller = build(backend: FakeBackend(), messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);

    controller.selection
      ..enter()
      ..select(['n2', 'n1']);

    expect(
      controller.selectionShareRoute(),
      shareSendPaths(ShareKind.network, ['n1', 'n2']),
    );
    expect(controller.selection.selecting.value, isFalse);
    expect(controller.selection.ids.value, isEmpty);
  });

  test('the selection share opens the bundle above the shell', () async {
    await seedWith({'n1': shareable('alpha'), 'n2': shareable('beta')});
    final pushed = <String>[];
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      pushed: pushed,
    );
    controller.start();
    addTearDown(controller.dispose);

    controller.selection
      ..enter()
      ..select(['n1', 'n2']);
    controller.openSelectionShare();

    expect(pushed, [
      shareSendPaths(ShareKind.network, ['n1', 'n2']),
    ]);
  });

  test('a selection past one bundle names the limit', () async {
    await seedWith({
      for (var index = 0; index <= shareMaxBundleItems; index++)
        'n$index': shareable('network-$index'),
    });
    final messages = <String>[];
    final controller = build(backend: FakeBackend(), messages: messages);
    controller.start();
    addTearDown(controller.dispose);

    controller.selection
      ..enter()
      ..toggleAll();
    expect(controller.selection.count.value, shareMaxBundleItems + 1);

    expect(controller.selectionShareRoute(), isNull);
    expect(messages, [
      strings.selectionTooMany(shareMaxBundleItems + 1, shareMaxBundleItems),
    ]);
    // The selection stays, so the user can take targets out and try again.
    expect(controller.selection.selecting.value, isTrue);
  });

  test('a selection with a network that cannot be shared reports it', () async {
    await seedWith({
      'n1': shareable('alpha'),
      'n2': Network()..networkName = 'beta',
    });
    final messages = <String>[];
    final pushed = <String>[];
    final controller = build(
      backend: FakeBackend(),
      messages: messages,
      pushed: pushed,
    );
    controller.start();
    addTearDown(controller.dispose);

    controller.selection
      ..enter()
      ..select(['n1', 'n2']);

    expect(controller.selectionShareRoute(), isNull);
    expect(messages, [strings.selectionUnavailable(1)]);
    // Nothing is pushed and the selection stays, so the user can drop the
    // network that cannot be shared.
    expect(pushed, isEmpty);
    expect(controller.selection.selecting.value, isTrue);
    expect(controller.selection.ids.value, {'n1', 'n2'});
  });

  test('records the instance events while refreshing', () async {
    await seedNetworks();
    final backend = FakeBackend(
      collected: () => {
        'alpha': {
          'running': true,
          'events': [
            '{"time":"2024-01-01T00:00:00Z","event":"TunDeviceReady"}',
          ],
        },
      },
    );
    final controller = build(backend: backend, messages: <String>[]);
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(instanceLogs('n1').value.single.kind, 'TunDeviceReady');
  });

  test('one TUN network runs, stays stoppable, and refuses the next', () async {
    await seedNetworks();
    final backend = FakeBackend(maxTunInstances: 1);
    final messages = <String>[];
    final controller = build(backend: backend, messages: messages);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.toggle('n1', true);
    await controller.refresh();

    // The running network is always stoppable...
    expect(controller.cards.value.first.onToggle, isNotNull);
    // ...while one that cannot start is not offered.
    expect(controller.cards.value.last.onToggle, isNull);
    await controller.toggle('n2', true);

    expect(messages, [strings.controllerOneNetwork]);
    expect(backend.started.keys, ['n1']);
  });

  test('a no-TUN network does not take the TUN slot', () async {
    await seedWith({
      'n1': Network()..networkName = 'alpha',
      'n2': (Network()..networkName = 'beta')..flags.noTun = true,
    });
    final backend = FakeBackend(maxTunInstances: 1);
    final controller = build(backend: backend, messages: <String>[]);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.toggle('n1', true);
    await controller.refresh();

    expect(controller.cards.value.last.onToggle, isNotNull);
    await controller.toggle('n2', true);

    expect(backend.started.keys, ['n1', 'n2']);
  });

  test('a refusal from a rule without a limit names one network', () async {
    await seedNetworks();
    final backend = _LimitlessRefusingBackend();
    final messages = <String>[];
    final controller = build(backend: backend, messages: messages);
    controller.start();
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggle('n1', true);

    expect(messages, [strings.controllerOneNetwork]);
    expect(backend.started, isEmpty);
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
    final controller = build(
      backend: CountingBackend(failCollect: true),
      messages: <String>[],
    );
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
    final backend = FakeBackend(
      collected: () => {
        'alpha': {'running': true},
      },
    );
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

  test(
    'a delete the store refuses keeps the network and is reported',
    () async {
      final messages = <String>[];
      await _seedWithFailingWrites();
      final controller = build(backend: FakeBackend(), messages: messages);
      addTearDown(controller.dispose);

      await controller.refresh();
      await controller.delete('n1');

      expect(saved.networks.value.keys, contains('n1'));
      expect(messages, [strings.controllerDeleteFailed('alpha')]);
    },
  );

  test(
    'reorder reports a store failure, and moves a network otherwise',
    () async {
      final messages = <String>[];
      await _seedWithFailingWrites();
      final failing = build(backend: FakeBackend(), messages: messages);
      addTearDown(failing.dispose);

      await failing.reorder(0, 2);

      expect(messages, [strings.controllerReorderFailed]);
      expect(saved.networks.value.keys.toList(), ['n1', 'n2']);

      await seedNetworks();
      final workingController = build(
        backend: FakeBackend(),
        messages: messages,
      );
      addTearDown(workingController.dispose);
      await workingController.reorder(1, 0);

      expect(saved.networks.value.keys.toList(), ['n2', 'n1']);
    },
  );

  test(
    'selection asks exactly once before invalid input is discarded',
    () async {
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
    },
  );

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
      backend: FakeBackend(
        collected: () => {
          'alpha': {'running': true},
        },
      ),
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
      backend: FakeBackend(
        collected: () => {
          'alpha': {'running': true},
        },
      ),
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
      pickConfig: () async =>
          const PickedConfig(name: 'taken.toml', content: content),
      validateConfig: (_) {},
    );
    addTearDown(rejected.dispose);

    await rejected.importFromFile();

    expect(messages, [
      strings.controllerImportInvalid(
        'taken.toml',
        strings.validationNetworkExists,
      ),
    ]);

    messages.clear();
    final invalid = build(
      backend: FakeBackend(),
      messages: messages,
      pickConfig: () async =>
          const PickedConfig(name: 'broken.toml', content: content),
      validateConfig: (_) => throw const FormatException('bad toml'),
    );
    addTearDown(invalid.dispose);

    await invalid.importFromFile();

    expect(messages.single, contains('broken.toml'));
    expect(messages.single, contains('FormatException: bad toml'));
  });

  test(
    'an unreadable file, and a dismissed picker, say what happened',
    () async {
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
    },
  );

  test('exports a network as its raw EasyTier TOML', () async {
    await seedNetworks();
    final messages = <String>[];
    final writes = <(String, String)>[];
    final controller = build(
      backend: FakeBackend(),
      messages: messages,
      saveExportFile: (name, content) async {
        writes.add((name, content));
        return true;
      },
    );
    addTearDown(controller.dispose);

    await controller.exportConfig('n1');

    final (name, content) = writes.single;
    expect(name, 'alpha.toml');
    expect(content, (await persisted('n1')).toEasyTierToml());
    expect(messages, [strings.controllerExported]);
  });

  test('a cancelled export is silent, a failed one is reported', () async {
    await seedNetworks();
    final messages = <String>[];
    final cancelled = build(
      backend: FakeBackend(),
      messages: messages,
      saveExportFile: (_, _) async => false,
    );
    addTearDown(cancelled.dispose);
    await cancelled.exportConfig('n1');
    expect(messages, isEmpty);

    final failing = build(
      backend: FakeBackend(),
      messages: messages,
      saveExportFile: (_, _) async => throw StateError('disk full'),
    );
    addTearDown(failing.dispose);
    await failing.exportConfig('n1');
    expect(messages.single, startsWith('Failed to export config:'));
  });

  test('an export suggests a file name every platform accepts', () {
    expect(exportFileName('home:1/2'), 'home_1_2.toml');
  });

  test('the periodic refresh exists only while something runs', () async {
    await seedNetworks();
    final backend = CountingBackend();
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

  // Nothing may write a signal once the controller is gone: each case leaves
  // its action in flight, disposes mid-await, and releases it afterwards.

  test('disposing during a refresh writes no disposed signal', () async {
    await seedNetworks();
    final backend = _GatedCollectBackend(fail: true);
    final controller = build(backend: backend, messages: <String>[]);

    final refreshing = controller.refresh();
    expect(controller.refreshing.value, isTrue);
    controller.dispose();
    backend.gate.complete();

    await expectLater(refreshing, completes);
    expect(controller.refreshing.peek(), isTrue, reason: 'the guard release');
    expect(controller.refreshError.peek(), isNull, reason: 'the error report');
    expect(
      instances.disposed,
      isFalse,
      reason: 'the shared store outlives the controller',
    );
  });

  test('disposing during a delete writes no disposed signal', () async {
    await seedNetworks();
    final confirm = Completer<bool>();
    final controller = build(
      backend: FakeBackend(),
      messages: <String>[],
      confirmDelete: (_) => confirm.future,
    );

    final deleting = controller.delete('n1');
    expect(controller.deleting.value, {'n1'});
    controller.dispose();
    confirm.complete(true);

    await expectLater(deleting, completes);
    expect(saved.networks.value.keys, ['n2'], reason: 'the delete still lands');
    expect(controller.deleting.peek(), {'n1'}, reason: 'the finally');
    expect(controller.transitions.peek(), isEmpty);
  });

  test('disposing during a start writes no disposed signal', () async {
    await seedNetworks();
    final backend = _GatedStartBackend();
    final controller = build(backend: backend, messages: <String>[]);
    await controller.refresh();

    final starting = controller.toggle('n1', true);
    await backend.entered.future;
    expect(controller.transitions.value['n1'], NetworkTransition.starting);
    controller.dispose();
    backend.gate.complete();

    await expectLater(starting, completes);
    expect(
      controller.transitions.peek()['n1'],
      NetworkTransition.starting,
      reason: 'the failed marker is not written after dispose',
    );
    expect(backend.started, isEmpty);
  });

  test('disposing during a stop writes no disposed signal', () async {
    await seedNetworks();
    final backend = _GatedStopBackend();
    final controller = build(backend: backend, messages: <String>[]);
    await controller.refresh();

    final stopping = controller.toggle('n1', false);
    await backend.entered.future;
    expect(controller.transitions.value['n1'], NetworkTransition.stopping);
    controller.dispose();
    backend.gate.complete();

    await expectLater(stopping, completes);
    expect(
      controller.transitions.peek()['n1'],
      NetworkTransition.stopping,
      reason: 'the removal is not written after dispose',
    );
  });

  test(
    'disposing while the discard dialog is open writes no selection',
    () async {
      await seedNetworks();
      final gate = Completer<void>();
      final controller = build(
        backend: FakeBackend(),
        messages: <String>[],
        invalidInput: () => true,
        confirmDiscardDialog: () async {
          await gate.future;
          return true;
        },
      );
      controller.start();
      expect(controller.selectedId.value, 'n1');

      // The selection is parked in the page's modal dialog when the page goes.
      final selecting = controller.select('n2');
      controller.dispose();
      gate.complete();

      await expectLater(selecting, completes);
      expect(
        controller.selectedId.peek(),
        'n1',
        reason: 'the late selection is dropped',
      );
    },
  );

  test(
    'disposing while the discard dialog is open leaves the tab alone',
    () async {
      await seedNetworks();
      final gate = Completer<void>();
      final controller = build(
        backend: FakeBackend(
          collected: () => {
            'alpha': {'running': true},
            'beta': {'running': true},
          },
        ),
        messages: <String>[],
        isWide: () => true,
        invalidInput: () => true,
        confirmDiscardDialog: () async {
          await gate.future;
          return true;
        },
      );
      controller.start();
      await controller.refresh();
      expect(controller.selectedId.value, 'n1');

      final logging = controller.log('n2');
      controller.dispose();
      gate.complete();

      await expectLater(logging, completes);
      expect(controller.selectedId.peek(), 'n1');
      expect(
        controller.instanceTab.peek(),
        InstanceTab.peers,
        reason: 'the late tab switch is dropped',
      );
    },
  );

  test('disposing while the save dialog is open writes no message', () async {
    await seedNetworks();
    final messages = <String>[];
    final gate = Completer<bool>();
    final controller = build(
      backend: FakeBackend(),
      messages: messages,
      saveExportFile: (_, _) => gate.future,
    );

    final exporting = controller.exportConfig('n1');
    controller.dispose();
    gate.complete(true);

    await expectLater(exporting, completes);
    expect(messages, isEmpty, reason: 'the page that would show it is gone');
  });
}

/// A backend whose collection waits for the test, then can fail.
class _GatedCollectBackend extends FakeBackend {
  _GatedCollectBackend({this.fail = false});

  final gate = Completer<void>();
  final bool fail;

  @override
  Future<Map<String, String>> collectInfos() async {
    await gate.future;
    if (fail) throw Exception('boom');
    return super.collectInfos();
  }
}

/// A backend whose first start waits for the test, then fails.
class _GatedStartBackend extends FakeBackend {
  final gate = Completer<void>();
  final entered = Completer<void>();

  @override
  Future<void> start(String id, Network network) async {
    entered.complete();
    await gate.future;
    throw Exception('no tun');
  }
}

/// A backend that reports one running instance and whose stop waits, then
/// fails.
class _GatedStopBackend extends FakeBackend {
  _GatedStopBackend()
    : super(
        collected: () => {
          'alpha': {'running': true},
        },
      );

  final gate = Completer<void>();
  final entered = Completer<void>();

  @override
  Future<void> stop(List<String> names) async {
    entered.complete();
    await gate.future;
    throw Exception('stuck');
  }
}

/// Seeds `n1`/`n2` into a store whose writes fail from now on.
Future<void> _seedWithFailingWrites() async {
  final store = await seedWith({
    'n1': Network()..networkName = 'alpha',
    'n2': Network()..networkName = 'beta',
  });
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

/// A backend whose capacity rule refuses without naming a limit, as an
/// override of the contract's own rule may.
class _LimitlessRefusingBackend extends FakeBackend {
  @override
  bool canStart(Network network, Iterable<Instance> running) => false;
}

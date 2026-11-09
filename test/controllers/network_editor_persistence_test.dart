import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:toml/toml.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_targets.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  setUp(seedNetworks);

  NetworkEditorController editor({List<String>? messages}) {
    final controller = NetworkEditorController(
      id: 'n1',
      showMessage: (message) => messages?.add(message),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'a burst updates the draft immediately and saves only its last value',
    () async {
      final controller = editor();
      final savedLast = Completer<void>();
      var notifications = 0;
      addTearDown(
        effect(() {
          final name = saved.networks.value['n1']!.networkName;
          notifications++;
          if (name == 'edit-19' && !savedLast.isCompleted) savedLast.complete();
        }),
      );

      for (var i = 0; i < 20; i++) {
        controller.update((network) => network.networkName = 'edit-$i');
      }
      expect(controller.name.peek(), 'edit-19');
      expect(saved.networks.peek()['n1']!.networkName, 'alpha');
      expect((await persisted('n1')).networkName, 'alpha');
      expect(saved.networkNames(), contains('edit-19'));
      expect(saved.networkNames(), contains('alpha'));

      await savedLast.future.timeout(const Duration(seconds: 5));
      await saved.settled();
      expect(notifications, 2);
      expect((await persisted('n1')).networkName, 'edit-19');
    },
  );

  test(
    'flush saves immediately and a later edit remains independent',
    () async {
      final controller = editor();
      controller.update((network) => network.hostname = 'first');
      final first = controller.flush();
      controller.update((network) => network.hostname = 'second');
      expect(await first, isTrue);
      expect((await persisted('n1')).hostname, 'first');
      expect(await controller.flush(), isTrue);
      expect((await persisted('n1')).hostname, 'second');
    },
  );

  test(
    'disposal flushes the last edit and further updates do nothing',
    () async {
      final controller = editor();
      controller.update((network) => network.hostname = 'last');
      controller.dispose();
      controller.update((network) => network.hostname = 'ignored');
      final reopened = editor();
      expect(reopened.working.peek()!.hostname, 'last');
      await saved.settled();
      expect((await persisted('n1')).hostname, 'last');
    },
  );

  test('deleting a network cancels its pending edit', () async {
    final messages = <String>[];
    final controller = editor(messages: messages);
    controller.update((network) => network.hostname = 'draft');
    await saved.deleteNetwork('n1');
    await controller.flush();
    expect(saved.networks.peek().containsKey('n1'), isFalse);
    expect(messages, isEmpty);
  });

  test(
    'sharing and export use the accepted draft before its timer fires',
    () async {
      final controller = editor();
      controller.update((network) {
        network.networkName = 'draft';
        network.nodes = [
          Node(
            url: Uri(scheme: 'tcp', host: 'relay.example.com', port: 11010),
            name: 'peer',
          ),
        ];
      });
      expect(
        resolveShareTarget(
          ShareKind.network,
          'n1',
        ).documents.single.toJson()['name'],
        'draft',
      );
      String? exported;
      final list = NetworkPageController(
        navigate: (_, _) {},
        showMessage: (_) {},
        confirmDelete: (_) async => true,
        showTunPermissionWarning: (_) async {},
        saveExportFile: (_, content) async {
          exported = content;
          return true;
        },
      );
      addTearDown(list.dispose);
      await list.exportConfig('n1');
      final identity =
          TomlDocument.parse(exported!).toMap()['network_identity'] as Map;
      expect(identity['network_name'], 'draft');
      expect(saved.networks.peek()['n1']!.networkName, 'alpha');
      final flushing = controller.flush();
      expect(saved.latestNetwork('n1')!.networkName, 'draft');
      await flushing;
    },
  );

  test('one failed save reports once and keeps the draft', () async {
    final store = await seedWith({'n1': Network()..networkName = 'alpha'});
    await store.file.delete();
    await Directory(store.file.path).create();
    final messages = <String>[];
    final controller = editor(messages: messages);
    for (var i = 0; i < 20; i++) {
      controller.update((network) => network.hostname = 'draft-$i');
    }
    expect(await controller.flush(), isFalse);
    expect(messages, hasLength(1));
    expect(controller.working.peek()!.hostname, 'draft-19');
    expect(saved.networks.peek()['n1']!.hostname, isNull);

    await Directory(store.file.path).delete();
    expect(await controller.flush(), isTrue);
    expect((await persisted('n1')).hostname, 'draft-19');
  });

  test('a disposed editor reports no late save error', () async {
    final store = await seedWith({'n1': Network()..networkName = 'alpha'});
    await store.file.delete();
    await Directory(store.file.path).create();
    final messages = <String>[];
    final controller = editor(messages: messages);
    controller.update((network) => network.hostname = 'draft');
    controller.dispose();
    await saved.settled();
    expect(messages, isEmpty);
    expect(saved.networks.peek()['n1']!.hostname, isNull);
  });

  test(
    'starting flushes accepted edits before the service reads its file',
    () async {
      final store = await seedWith({'n1': Network()..networkName = 'alpha'});
      final backend = _ReadingBackend(store);
      final list = NetworkPageController(
        navigate: (_, _) {},
        showMessage: (_) {},
        confirmDelete: (_) async => true,
        showTunPermissionWarning: (_) async {},
        backend: backend,
      );
      addTearDown(list.dispose);
      await list.refresh();
      final controller = editor();
      controller.update((network) => network.hostname = 'latest');

      await list.toggle('n1', true);

      expect(backend.readHostname, 'latest');
    },
  );
}

class _ReadingBackend extends FakeBackend {
  _ReadingBackend(this.store);
  final NetworkStore store;
  String? readHostname;

  @override
  Future<void> start(String id, Network network) async {
    readHostname = (await store.load())[id]!.hostname;
    await super.start(id, network);
  }
}

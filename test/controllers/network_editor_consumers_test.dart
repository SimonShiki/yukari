import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari/controllers/bookmarks_actions.dart';
import 'package:yukari/controllers/bookmarks_controller.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/system/tray_networks.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/models.dart';

import '../async_support.dart';
import '../bookmarks_fixture.dart';
import '../fake_backend.dart';
import '../fake_service_control.dart';
import '../networks_fixture.dart';

void main() {
  late NetworkEditorController editor;

  setUp(() async {
    await seedNetworks();
    editor = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(editor.dispose);
    editor.update((network) => network.hostname = 'draft-host');
  });

  test('the tray starts the network with accepted edits', () async {
    final backend = FakeBackend();
    final active = signal<NetworkBackend>(backend);
    addTearDown(active.dispose);
    final tray = TrayNetworkActions(active);

    expect(await tray.toggle('n1', true), isTrue);

    expect(backend.started['n1']!.hostname, 'draft-host');
    expect((await persisted('n1')).hostname, 'draft-host');
  });

  test('a failed edit save prevents starting with stale settings', () async {
    final store = await seedWith({'n1': Network()..networkName = 'alpha'});
    await store.file.delete();
    await Directory(store.file.path).create();
    editor.update((network) => network.hostname = 'unsaved');
    final backend = FakeBackend();
    final list = NetworkPageController(
      navigate: (_, _) {},
      showMessage: (_) {},
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: backend,
    );
    addTearDown(list.dispose);
    await list.refresh();

    await list.toggle('n1', true);

    expect(backend.started, isEmpty);
    expect(editor.working.peek()!.hostname, 'unsaved');
  });

  test('adding a bookmark preserves pending configuration edits', () async {
    final bookmarks = BookmarksController(showMessage: (_) {});
    addTearDown(bookmarks.dispose);
    final bookmark = testBookmark('relay', host: 'relay.example.com');

    await bookmarks.addToNetwork(bookmark, 'n1');
    await editor.flush();

    final network = await persisted('n1');
    expect(network.hostname, 'draft-host');
    expect(network.nodes.single.id, bookmark.node.id);
  });

  test('starting the service flushes edits before invoking the OS', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final control = FakeServiceControl(
      current: ServiceState.stopped,
      actionGate: gate,
    );
    final backend = signal<NetworkBackend>(FakeBackend());
    addTearDown(backend.dispose);
    final settings = BackendSettingsController(
      showMessage: (_) {},
      confirmStopNetworks: (_, _) async => true,
      control: control,
      backend: backend,
      probeVersion: () async => null,
    );
    addTearDown(settings.dispose);

    final starting = settings.start();
    await waitFor(() => control.calls.contains('start'));
    expect((await persisted('n1')).hostname, 'draft-host');
    gate.complete();
    await starting;
  });
}

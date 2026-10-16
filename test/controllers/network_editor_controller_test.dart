import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/controllers/network_editor_security.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/signals/bookmarks.dart' as saved_bookmarks;
import 'package:yukari/signals/networks.dart' as saved;

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  Node peer(String id) => Node(
    id: id,
    url: Uri.parse('relay.example.com'),
    port: 11010,
    protocols: const [NodeProtocol.tcp],
  );

  test('holds a deep working copy and never corrupts the stored one', () async {
    await seedNetworks();
    final controller = NetworkEditorController(
      id: 'n1',
      showMessage: (_) {},
    );
    addTearDown(controller.dispose);

    controller.update((n) {
      n.networkName = 'renamed';
      n.hostname = 'me';
    });

    expect(controller.working.value!.networkName, 'renamed');
    expect(controller.name.value, 'renamed');
    // The stored network still holds the old value until the write lands.
    expect(saved.networks.value['n1']!.networkName, 'alpha');

    await saved.settled();

    expect(saved.networks.value['n1']!.networkName, 'renamed');
    expect((await persisted('n1')).hostname, 'me');
    expect(controller.working.value!.updatedAt.isUtc, isTrue);

    // A later edit works on a copy, so the value already stored stays intact.
    final stored = saved.networks.value['n1']!;
    controller.update((n) => n.networkName = 'again');
    await saved.settled();
    expect(stored.networkName, 'renamed');
  });

  test('an unknown id has no working copy', () {
    final controller = NetworkEditorController(id: 'gone', showMessage: (_) {});
    addTearDown(controller.dispose);

    expect(controller.working.value, isNull);
    expect(controller.missing.value, isTrue);
    expect(controller.name.value, '');
  });

  test('a write the store refuses is reported and kept on screen', () async {
    final store = temporaryStore();
    await store.save({'n1': Network()..networkName = 'alpha'});
    await saved.init(store);
    addTearDown(saved.dispose);
    // A directory where the store writes makes every save fail.
    store.file.deleteSync();
    Directory(store.file.path).createSync(recursive: true);
    final messages = <String>[];
    final controller = NetworkEditorController(
      id: 'n1',
      showMessage: messages.add,
    );
    addTearDown(controller.dispose);

    controller.update((n) => n.networkName = 'kept');
    await saved.settled();
    await pumpEventQueue();

    expect(controller.working.value!.networkName, 'kept');
    expect(messages.single, startsWith(strings.controllerSave('')));
  });

  test('the bundled shared nodes are injectable', () async {
    await seedNetworks();
    final withBuiltins = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(withBuiltins.dispose);
    expect(withBuiltins.sharedBookmarks, builtinBookmarks);
    expect(withBuiltins.pickableBookmarks, builtinBookmarks);

    final without = NetworkEditorController(
      id: 'n1',
      showMessage: (_) {},
      sharedBookmarks: const [],
    );
    addTearDown(without.dispose);
    expect(without.sharedBookmarks, isEmpty);
    expect(without.pickableBookmarks, isEmpty);
  });

  test('adds, replaces and removes peers', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.addPeer(peer('a'));
    controller.addPeer(peer('b'));
    expect(controller.nodes.value.map((node) => node.id), ['a', 'b']);

    controller.addPeer(peer('a')..port = 12000);
    expect(controller.nodes.value.map((node) => node.id), ['a', 'b']);
    expect(controller.nodes.value.first.port, 12000);

    controller.removePeer('a');
    expect(controller.nodes.value.map((node) => node.id), ['b']);
    await saved.settled();
    expect((await persisted('n1')).nodes.single.id, 'b');
  });

  test('adds, replaces and removes listeners', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);
    final tcp = Uri.parse('tcp://0.0.0.0:11010');
    final udp = Uri.parse('udp://0.0.0.0:11010');

    controller.setListener(ListenerList.local, tcp);
    controller.setListener(ListenerList.local, udp);
    controller.setListener(ListenerList.mapped, udp);
    expect(controller.listeners.value, [tcp, udp]);
    expect(controller.mappedListeners.value, [udp]);

    controller.setListener(ListenerList.local, udp, previous: tcp);
    expect(controller.listeners.value, [udp, udp]);

    controller.removeListener(ListenerList.local, udp);
    expect(controller.listeners.value, isEmpty);
    expect(controller.mappedListeners.value, [udp]);
    await saved.settled();
    expect((await persisted('n1')).mappedListeners, [udp]);
  });

  test('adds picked bookmarks as peer copies', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.addBookmarks([testBookmark('b1', host: 'one.example.com')]);
    controller.addBookmarks([testBookmark('b1', host: 'one.example.com')]);

    expect(controller.nodes.value, hasLength(1));
    expect(nodeHost(controller.nodes.value.single.url), 'one.example.com');
  });

  test('saving a peer as a bookmark toggles it', () async {
    await seedBookmarks();
    await seedNetworks();
    final messages = <String>[];
    final controller = NetworkEditorController(
      id: 'n1',
      showMessage: messages.add,
    );
    addTearDown(controller.dispose);
    final node = peer('a');
    controller.addPeer(node);

    expect(controller.bookmarkedNode(node).value, isFalse);
    await controller.toggleBookmark(node);

    expect(controller.bookmarkedNode(node).value, isTrue);
    expect(saved_bookmarks.bookmarks.value.single.name, 'a');
    expect(messages, [strings.bookmarksSaved]);

    await controller.toggleBookmark(node);

    expect(controller.bookmarkedNode(node).value, isFalse);
    expect(saved_bookmarks.bookmarks.value, isEmpty);
    expect(messages, [strings.bookmarksSaved, strings.bookmarksRemoved]);
  });

  test('secure mode generates a key pair and keeps it when disabled', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.setSecureMode(true);

    final mode = controller.working.value!.secureMode!;
    expect(mode.enabled, isTrue);
    expect(base64.decode(mode.localPrivateKey!), hasLength(32));
    expect(mode.localPublicKey, isNull);

    await pumpEventQueue();

    expect(base64.decode(controller.working.value!.secureMode!.localPublicKey!), hasLength(32));

    controller.setSecureMode(false);

    expect(controller.working.value!.secureMode!.enabled, isFalse);
    expect(controller.working.value!.secureMode!.localPrivateKey, isNotNull);
    expect(controller.working.value!.secureMode!.localPublicKey, isNotNull);
  });

  test('generating a key pair replaces both keys', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.setSecureMode(true);
    await pumpEventQueue();
    final first = controller.working.value!.secureMode!.localPrivateKey;

    controller.generateKeyPair();
    await pumpEventQueue();

    final mode = controller.working.value!.secureMode!;
    expect(mode.localPrivateKey, isNot(first));
    expect(mode.localPublicKey, isNotNull);
  });

  test('clearing the private key clears the pair and secure mode', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.setSecureMode(true);
    await pumpEventQueue();

    controller.setPrivateKey('');

    final mode = controller.working.value!.secureMode!;
    expect(mode.enabled, isFalse);
    expect(mode.localPrivateKey, isNull);
    expect(mode.localPublicKey, isNull);
  });

  test('the VPN portal is created with a key and address, and kept', () async {
    await seedNetworks();
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);

    controller.setVpnPortal(true);

    final portal = controller.working.value!.vpnPortal!;
    expect(portal.enabled, isTrue);
    expect(portal.wireguardListen, '0.0.0.0:22022');
    expect(base64.decode(portal.wireguardPrivateKey!), hasLength(32));

    controller.setWireguardListen('0.0.0.0:22023');
    controller.setVpnPortal(false);

    final kept = controller.working.value!.vpnPortal!;
    expect(kept.enabled, isFalse);
    expect(kept.wireguardListen, '0.0.0.0:22023');
    expect(kept.wireguardPrivateKey, isNotNull);
  });
}

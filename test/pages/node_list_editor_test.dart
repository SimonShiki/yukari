import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/widgets/peer_list.dart';
import 'package:yukari/signals/bookmarks.dart' as bookmarks;
import 'package:yukari/signals/networks.dart' as saved;

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';
import 'network_test_support.dart';

void main() {
  useDeterministicCursor();

  late NetworkEditorController controller;

  Future<void> pumpPeers(
    WidgetTester tester, {
    List<Node> nodes = const [],
    List<Bookmark>? sharedBookmarks,
  }) async {
    await tester.runAsync(
      () => seedWith({'n1': seededNetwork(nodes: nodes)}),
    );
    controller = NetworkEditorController(
      id: 'n1',
      showMessage: (_) {},
      sharedBookmarks: sharedBookmarks,
    );
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      NetworkEditorPage(id: 'n1', controller: controller),
    );
  }

  Node node(String id, {int port = 11010}) => Node(
    id: id,
    url: Uri.parse('relay.example.com'),
    port: port,
    protocols: const [NodeProtocol.tcp],
  );

  testWidgets('the empty peer list warns and offers the bookmarks', (
    tester,
  ) async {
    await pumpPeers(tester);

    expect(find.text(strings.peersEmptyWarning), findsOneWidget);
    expect(find.text(strings.peersEmptyNoPublic), findsNothing);
    // The action, not a second copy of the notice text.
    expect(find.text(strings.peersEmptyAddPublic), findsOneWidget);
    expect(find.text(strings.peersEmptyBrowse), findsOneWidget);
    expect(find.text(strings.networkNoConfiguredPeers), findsOneWidget);
  });

  testWidgets('the empty peer list says when no public nodes are bundled', (
    tester,
  ) async {
    await pumpPeers(tester, sharedBookmarks: const []);

    expect(find.text(strings.peersEmptyWarning), findsOneWidget);
    expect(find.text(strings.peersEmptyNoPublic), findsOneWidget);
    expect(find.text(strings.peersEmptyAddPublic), findsNothing);
    expect(find.text(strings.peersEmptyBrowse), findsOneWidget);
  });

  testWidgets('the peer dialog flags every invalid field', (tester) async {
    await pumpPeers(tester);

    await tapSaving(tester, find.text(strings.networkAddPeer));
    await tester.tap(find.text(strings.commonSave));
    await tester.pumpAndSettle();

    expect(find.text(strings.networkPeerIdEmpty), findsOneWidget);
    expect(find.text(strings.validationHostEmpty), findsOneWidget);
    expect(
      find.text(strings.validationRange(strings.networkPort, '1', '65535')),
      findsOneWidget,
    );
    expect(find.text(strings.networkProtocolRequired), findsOneWidget);
    // The dialog stays open.
    expect(find.text(strings.networkAddPeer), findsWidgets);
  });

  testWidgets('a valid peer is added and saved', (tester) async {
    await pumpPeers(tester);

    // The dialog's validation is locked above; the save itself runs in the
    // real zone, because file IO started under the fake clock never completes.
    await tester.runAsync(() async {
      controller.addPeer(node('peer-x'));
      await saved.settled();
    });
    await tester.pumpAndSettle();

    expect(find.text('peer-x'), findsOneWidget);
    // The row shows the protocols, not the endpoint URLs.
    expect(find.text('TCP'), findsOneWidget);
    expect(find.textContaining('relay.example.com'), findsNothing);
  });

  testWidgets('the peer dialog opens on the peer it edits', (tester) async {
    await pumpPeers(tester, nodes: [node('peer-x')]);

    await tapVisible(tester, find.text('peer-x'));

    expect(find.text(strings.networkEditPeerNamed('peer-x')), findsOneWidget);
    expect(find.text('11010'), findsWidgets);
  });

  testWidgets('a peer is saved as a bookmark and removed again', (tester) async {
    await tester.runAsync(seedBookmarks);
    await pumpPeers(tester, nodes: [node('peer-x')]);

    expect(find.byTooltip(strings.peersSaveToBookmarks), findsOneWidget);

    await tapSaving(tester, find.byTooltip(strings.peersSaveToBookmarks));

    expect(bookmarks.bookmarks.value.single.name, 'peer-x');
    expect(find.byTooltip(strings.peersRemoveBookmark), findsOneWidget);

    await tapSaving(tester, find.byTooltip(strings.peersRemoveBookmark));

    expect(bookmarks.bookmarks.value, isEmpty);
    expect(find.byTooltip(strings.peersSaveToBookmarks), findsOneWidget);
  });

  testWidgets('a bookmark change rebuilds one peer row only', (tester) async {
    await tester.runAsync(seedBookmarks);
    await pumpPeers(tester, nodes: [node('peer-x'), node('peer-y')]);

    final other = tester.widget<PeerRow>(find.byType(PeerRow).at(1));

    await tapSaving(
      tester,
      find.byTooltip(strings.peersSaveToBookmarks).first,
    );

    expect(controller.bookmarkedNode(node('peer-x')).value, isTrue);
    expect(
      identical(tester.widget<PeerRow>(find.byType(PeerRow).at(1)), other),
      isTrue,
      reason: 'the untouched peer row rebuilt',
    );
  });

  testWidgets('a truncated peer id can be revealed, a short one cannot', (
    tester,
  ) async {
    final longId = 'peer-${'x' * 60}';
    await pumpPeers(tester, nodes: [node('peer-x'), node(longId)]);

    expect(find.byTooltip(longId), findsOneWidget);
    expect(find.byTooltip('peer-x'), findsNothing);
  });

  testWidgets('the picker offers the saved bookmarks to add', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([testBookmark('b1', name: 'Relay One')]),
    );
    await pumpPeers(tester);

    // Picking appends the node through the controller, which is what the
    // controller test saves; here the picker's own state is locked.
    await tapVisible(tester, find.text(strings.bookmarksFromBookmarks));
    expect(find.text(strings.bookmarksPickerTitle), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    expect(find.text(strings.bookmarksPickerAdd(1)), findsOneWidget);

    await tester.tap(find.text(strings.commonCancel));
    await tester.pumpAndSettle();

    expect(find.text(strings.bookmarksPickerTitle), findsNothing);
    expect(controller.nodes.value, isEmpty);
  });

  testWidgets('the shared nodes are offered on their own', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([testBookmark('mine', name: 'My Node')]),
    );
    await pumpPeers(tester);

    await tapVisible(
      tester,
      find.widgetWithText(TextButton, strings.peersEmptyAddPublic),
    );

    // Only the bundled shared nodes are offered.
    expect(find.text(strings.bookmarksPickerTitle), findsOneWidget);
    expect(find.text('My Node'), findsNothing);
    expect(find.byType(CheckboxListTile), findsWidgets);
  });
}

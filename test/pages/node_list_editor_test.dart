import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/node.dart';
import 'package:yukari/pages/networks/widgets/node_list_editor.dart';
import 'package:yukari/signals/bookmarks.dart';

import '../bookmarks_fixture.dart';

void main() {
  late List<Node> nodes;

  setUp(() async {
    nodes = [];
    await seedBookmarks();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => NodeListEditor(
                nodes: nodes,
                onNodesChanged: (value) => setState(() => nodes = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> act(WidgetTester tester, void Function() action) async {
    await tester.runAsync(() async {
      action();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await settled();
    });
    await tester.pump();
  }

  testWidgets('warns that a network without initial peers may not connect', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text(
        'This network has no initial peers, so it may not find anyone. '
        'Add a public node so it connects correctly.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No public nodes are bundled yet. Add a peer, or save one as a bookmark.',
      ),
      findsNothing,
    );
    expect(find.text('No peers configured'), findsOneWidget);
    expect(find.text('Browse Bookmarks'), findsWidgets);
    expect(find.text('Add a Public Node'), findsOneWidget);
  });

  testWidgets('adds bookmarks to the initial peers', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
      ]),
    );
    await pump(tester);

    await tester.tap(find.text('From Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Add from Bookmarks'), findsOneWidget);

    await tester.tap(find.text('Home relay'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1'));
    await tester.pumpAndSettle();

    expect(nodes.single.id, 'b1');
    expect(nodeHost(nodes.single.url), 'relay.example.com');
    expect(find.text('b1'), findsOneWidget);
  });

  testWidgets('saves a peer as a bookmark and removes it again', (
    tester,
  ) async {
    nodes = [
      Node(
        id: 'relay',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
    ];
    await pump(tester);

    await act(tester, () async {
      await tester.tap(find.byTooltip('Save to bookmarks'));
    });
    await tester.pumpAndSettle();

    expect(bookmarks.value.single.node.id, 'relay');
    expect(bookmarks.value.single.name, 'relay');
    expect(persistedBookmarks().single.id, bookmarks.value.single.id);

    await act(tester, () async {
      await tester.tap(find.byTooltip('Remove from bookmarks'));
    });
    await tester.pumpAndSettle();

    expect(bookmarks.value, isEmpty);
  });
}

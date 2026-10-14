import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/controllers/bookmarks_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/bookmark.dart';
import 'package:yukari/models/node.dart';
import 'package:yukari/pages/bookmarks/bookmarks_page.dart';
import 'package:yukari/pages/bookmarks/widgets/bookmark_list_item.dart';
import 'package:yukari/signals/bookmarks.dart';
import 'package:yukari/signals/networks.dart' as saved_networks;

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';

void main() {
  late List<String> messages;

  setUp(() async {
    messages = [];
    await seedNetworks();
    await seedBookmarks();
  });

  Future<BookmarksController> pump(
    WidgetTester tester, {
    List<Bookmark>? builtins,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = BookmarksController(
      showMessage: messages.add,
      builtins: builtins,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: BookmarksPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Drives [body] in the real zone, where the bookmark store's file writes
  /// actually complete, so each UI flow can be followed to the end.
  Future<void> real(WidgetTester tester, Future<void> Function() body) =>
      tester.runAsync(body);

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('shows the empty state and saves a new bookmark', (tester) async {
    await real(tester, () async {
      // Without bundling a shared node, so the page opens on its empty state.
      await pump(tester, builtins: const []);

      expect(find.text('No bookmarks yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add Bookmark'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Peer ID'), 'relay');
      await tester.enterText(field('URL'), 'relay.example.com');
      await tester.enterText(field('Port'), '11010');
      await tester.enterText(field('Name (Optional)'), 'Home relay');
      await tester.tap(find.text('TCP'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settled();
      await tester.pumpAndSettle();

      expect(bookmarks.value.single.node.id, 'relay');
      expect(bookmarks.value.single.name, 'Home relay');
      expect(find.text('Home relay'), findsOneWidget);
      expect(persistedBookmarks().single.id, bookmarks.value.single.id);
    });
  });

  testWidgets('the edit dialog keeps the first field label in view', (
    tester,
  ) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
      ]),
    );
    await pump(tester);

    await tester.tap(find.byTooltip('More options for Home relay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Bookmark'));
    await tester.pumpAndSettle();

    // The floating label of the first field used to be sliced off by the
    // scroll view's top edge.
    final viewport = tester.getRect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final label = tester.getRect(find.text('Name (Optional)'));
    expect(label.top, greaterThanOrEqualTo(viewport.top));
    expect(label.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('tapping a bookmark opens it for editing', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark(
          'b1',
          host: 'relay.example.com',
          name: 'Home relay',
          tags: const ['fast'],
        ),
      ]),
    );
    await pump(tester);

    await tester.tap(find.text('Home relay'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Bookmark'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Home relay'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'fast'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'relay.example.com'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a shared node does not open an editor', (tester) async {
    await pump(
      tester,
      builtins: [
        testBookmark(
          'builtin:shared',
          host: 'shared.example.com',
          name: 'Community relay',
        ),
      ],
    );

    await tester.tap(find.text('Community relay'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('searches the saved bookmarks', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
        testBookmark('b2', host: 'office.example.com', name: 'Office relay'),
      ]),
    );
    final controller = await pump(tester);

    expect(find.text('Home relay'), findsOneWidget);
    expect(find.text('Office relay'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'office');
    await tester.pumpAndSettle();

    expect(find.text('Home relay'), findsNothing);
    expect(find.text('Office relay'), findsOneWidget);

    controller.clearFilters();
    await tester.pumpAndSettle();
    expect(controller.visible.value.length, builtinBookmarks.length + 2);
  });

  testWidgets('filters by category and tag from the sidebar', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark(
          'b1',
          host: 'relay.example.com',
          name: 'Home relay',
          category: 'Home',
          tags: const ['fast'],
        ),
        testBookmark(
          'b2',
          host: 'public.example.com',
          name: 'Public relay',
          category: 'Public',
          tags: const ['fast'],
        ),
      ]),
    );
    await pump(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CheckboxListTile, 'Home'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Public'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, '#fast'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home relay'), findsOneWidget);
    expect(find.text('Public relay'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, '#fast'));
    await tester.pumpAndSettle();
    expect(find.text('Home relay'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Home relay'), findsOneWidget);
    expect(find.text('Public relay'), findsOneWidget);
  });

  testWidgets('adds the bookmark to the chosen network', (tester) async {
    await real(tester, () async {
      await seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
      ]);
      await pump(tester);

      // Only the saved bookmark's own row, not the bundled shared nodes.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(BookmarkListItem, 'Home relay'),
          matching: find.byTooltip('Add to Network'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add to which network?'), findsOneWidget);

      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      // The picker's continuation and the queued write both run on the real
      // event loop, which needs a turn before the queue can be awaited.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await saved_networks.settled();

      expect(
        nodeHost(saved_networks.networks.value['n1']!.nodes.single.url),
        'relay.example.com',
      );
      expect(messages, contains('Added to alpha'));
    });
  });

  testWidgets('deletes a bookmark after confirmation', (tester) async {
    await real(tester, () async {
      await seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
      ]);
      await pump(tester);

      await tester.tap(find.byTooltip('More options for Home relay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Home relay?'), findsOneWidget);
      expect(
        find.text(
          'It leaves this list only; networks that already use the node '
          'keep their peer.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await settled();
      await tester.pumpAndSettle();

      expect(bookmarks.value, isEmpty);
      expect(persistedBookmarks(), isEmpty);
      expect(find.text('No bookmarks yet'), findsOneWidget);
    });
  });

  testWidgets('lists built-in shared nodes as read-only', (tester) async {
    await pump(
      tester,
      builtins: [
        testBookmark(
          'builtin:shared',
          host: 'shared.example.com',
          name: 'Community relay',
          category: 'Public',
          tags: const ['public'],
        ),
      ],
    );

    expect(find.text('Shared Nodes'), findsOneWidget);
    expect(find.text('Community relay'), findsOneWidget);
    // Once on the bookmark, and as the category and tag it carries.
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('#public'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(find.byTooltip('Add to Network'), findsOneWidget);

    await tester.tap(find.byTooltip('More options for Community relay'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);

    // The built-in node's edit and delete actions are disabled.
    await tester.tap(find.text('Edit Bookmark'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookmarks.value, isEmpty);
  });

  testWidgets('offers the share channels, stubs included', (tester) async {
    await tester.runAsync(
      () => seedBookmarks([
        testBookmark('b1', host: 'relay.example.com', name: 'Home relay'),
      ]),
    );
    await pump(tester);

    await tester.tap(find.byTooltip('More options for Home relay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share Home relay'), findsOneWidget);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Export as JSON'), findsOneWidget);

    await tester.tap(find.text('Send over network'));
    await tester.pumpAndSettle();

    expect(
      messages,
      contains('Sending over a network arrives with the data plane'),
    );
  });

  testWidgets('the add menu carries import and QR scanning', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add Bookmark'), findsWidgets);
    expect(find.text('Import from file'), findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);

    await tester.tap(find.text('Scan QR Code'));
    await tester.pumpAndSettle();

    expect(
      messages,
      contains('Scanning a bookmark from a QR code is coming soon.'),
    );
  });
}

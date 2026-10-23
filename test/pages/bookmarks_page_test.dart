import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/controllers/bookmarks_actions.dart';
import 'package:yukari/controllers/bookmarks_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari/pages/bookmarks/bookmarks_page.dart';
import 'package:yukari/pages/share/qr_share_receive_page.dart';
import 'package:yukari/pages/share/qr_share_send_page.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';
import 'package:yukari/signals/bookmarks.dart' as saved;
import 'package:yukari/signals/networks.dart' as networks;
import 'package:yukari/utils/bookmark_codec.dart';
import 'package:yukari/widgets/selection/selection_chrome.dart';
import 'package:yukari/widgets/metadata_chip/metadata_chip.dart';

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  late List<String> messages;

  setUp(() => messages = []);

  /// The share routes the app serves, so the page's `context.push` lands on
  /// the real pages.
  GoRouter shareRouter(BookmarksController controller) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BookmarksPage(controller: controller),
      ),
      GoRoute(
        path: shareSendRoutePattern,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: QrShareSendPage(
            kind: ShareKind.values.asNameMap()[state.pathParameters['kind']]!,
            ids: shareSendIds(state.pathParameters['id']),
          ),
        ),
      ),
      GoRoute(
        path: shareReceivePath,
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const QrShareReceivePage()),
      ),
    ],
  );

  /// Pumps the page with an injected controller.
  ///
  /// The caller runs the whole test inside [WidgetTester.runAsync], because
  /// the signal stores write real files and a store future never completes in
  /// the fake-async zone a widget test otherwise runs in.
  Future<BookmarksController> pumpPage(
    WidgetTester tester, {
    List<Bookmark> builtins = const [],
    BookmarkFilePicker? pickImportFile,
    BookmarkFileSaver? saveExportFile,
    Size size = const Size(800, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = BookmarksController(
      showMessage: messages.add,
      builtins: builtins,
      pickImportFile: pickImportFile,
      saveExportFile: saveExportFile,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: shareRouter(controller),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Lets the store writes a UI interaction started reach the disk.
  Future<void> settleStores() async {
    await Future<void>.delayed(Duration.zero);
    await saved.settled();
    await networks.settled();
    await Future<void>.delayed(Duration.zero);
  }

  /// Opens a row's overflow menu.
  Future<void> openMenu(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('More options for $name'));
    await tester.pumpAndSettle();
  }

  /// Opens the row's share sheet.
  Future<void> openShare(WidgetTester tester, String name) async {
    await openMenu(tester, name);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
  }

  /// Opens the action menu, whose items stagger in on real timers.
  Future<void> openFabMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('the empty state creates a bookmark through the editor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      await pumpPage(tester);

      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(
        find.text(
          'Save a node from a network, or add one here to reuse it in every network.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SearchBar), findsNothing, reason: 'nothing to search');

      await tester.tap(find.widgetWithText(FilledButton, 'Add Bookmark'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name (Optional)'),
        'Mine',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Peer ID'),
        'peer1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'URL'),
        'peer.example.com',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Port'), '11010');
      // The protocol chips sit below the fold of the scrollable dialog.
      await tester.ensureVisible(find.text('TCP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TCP'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await settleStores();

      expect(find.text('Mine'), findsOneWidget);
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('My Bookmarks'), findsOneWidget);
      expect(persistedBookmarks().single.name, 'Mine');
      expect(persistedBookmarks().single.id, isNot('peer1'));
    });
  });

  testWidgets('keeps the search field in the app bar, flat', (tester) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(SearchBar),
        ),
        findsOneWidget,
      );
      final bar = tester.widget<SearchBar>(find.byType(SearchBar));
      expect(
        bar.elevation?.resolve(<WidgetState>{}),
        0,
        reason: 'the field belongs to the app bar, so it floats over nothing',
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).scrolledUnderElevation,
        0,
        reason: 'no scrolled-under shadow over the search field',
      );
    });
  });

  testWidgets('hides the app bar search when there is nothing at all', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      await pumpPage(tester);

      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(SearchBar),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('the editor stays open while the node fields are invalid', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add Bookmark'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Peer ID cannot be empty'), findsOneWidget);
      expect(persistedBookmarks(), isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  testWidgets('taps a saved row to edit it and shows the trimmed category', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'One', category: ' Home ', tags: ['relay']),
      ]);
      final semantics = tester.ensureSemantics();
      await pumpPage(tester);

      expect(find.text('Home'), findsOneWidget, reason: 'trimmed overline');
      expect(find.text(' Home '), findsNothing);
      expect(find.bySemanticsLabel('Edit One'), findsOneWidget);
      semantics.dispose();
      expect(find.text('#relay'), findsOneWidget);
      expect(find.text('relay.example.com:11010'), findsOneWidget);

      // Tapping the row opens the editor, labelled for accessibility.
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit Bookmark'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name (Optional)'),
        'Renamed',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await settleStores();

      expect(find.text('Renamed'), findsOneWidget);
      expect(persistedBookmarks().single.id, 'u1');
      expect(persistedBookmarks().single.name, 'Renamed');

      // The overflow menu edits too, and closing it leaves nothing behind.
      await openMenu(tester, 'Renamed');
      await tester.tap(find.text('Edit Bookmark'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('keeps the shared nodes read-only and untappable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      await pumpPage(
        tester,
        builtins: [
          testBookmark(
            'builtin:one',
            name: 'Shared One',
            category: ' Shared ',
            tags: ['relay'],
          ),
        ],
      );

      expect(find.text('Shared Nodes'), findsOneWidget);
      expect(find.text('Community-provided public nodes'), findsOneWidget);
      expect(find.text('Shared One'), findsOneWidget);
      expect(find.text('My Bookmarks'), findsOneWidget);
      expect(find.text('No bookmarks yet'), findsOneWidget);

      await tester.tap(find.text('Shared One'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: 'tappable row');

      await openMenu(tester, 'Shared One');
      await tester.tap(find.text('Edit Bookmark'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: 'enabled edit');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: 'enabled delete');

      // Sharing a built-in is not editing it, so it stays available.
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(find.text('Share Shared One'), findsOneWidget);
    });
  });

  testWidgets('renders the bundled shared nodes', (tester) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      await pumpPage(tester, builtins: builtinBookmarks);

      expect(find.text('Shared Nodes'), findsOneWidget);
      expect(find.text(builtinBookmarks.first.displayName), findsOneWidget);
      expect(
        find.textContaining(sharedNodeCategory),
        findsWidgets,
        reason: 'the built-in category overline',
      );
    });
  });

  testWidgets('tones the protocol and tag chips with the metadata tokens', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark(
          'u1',
          name: 'Alpha',
          host: 'one.example.com',
          tags: ['relay'],
        ),
      ]);
      await pumpPage(tester);
      final colors = Theme.of(tester.element(find.byType(BookmarksPage)))
          .colorScheme;

      Badge chip(String label) => tester.widget<Badge>(
        find.ancestor(of: find.text(label), matching: find.byType(Badge)),
      );

      expect(
        tester
            .widget<MetadataChip>(find.widgetWithText(MetadataChip, 'TCP'))
            .tone,
        MetadataChipTone.protocol,
      );
      expect(chip('TCP').backgroundColor, colors.secondaryContainer);
      expect(chip('TCP').textColor, colors.onSecondaryContainer);
      expect(chip('#relay').backgroundColor, colors.surfaceContainerHighest);
      expect(chip('#relay').textColor, colors.onSurfaceVariant);
      // The regression: a bare Badge took these, so `TCP` read as a failure.
      expect(chip('TCP').backgroundColor, isNot(colors.errorContainer));
      expect(chip('TCP').backgroundColor, isNot(colors.error));
    });
  });

  testWidgets('reveals a truncated bookmark name on long-press', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const longName =
          'A very long bookmark name that cannot fit on one phone line';
      await seedBookmarks([
        testBookmark('u1', name: longName, host: 'one.example.com'),
      ]);
      await pumpPage(tester, size: const Size(360, 800));

      expect(find.text(longName), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text(longName), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, longName, reason: 'the full name is revealable');
    });
  });

  testWidgets('leaves a name that fits without a tooltip', (tester) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(tester, size: const Size(360, 800));

      expect(find.text('Alpha'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('Alpha'), matching: find.byType(Tooltip)),
        findsNothing,
      );
    });
  });

  testWidgets('searches the rows and clears the query from the field', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
        testBookmark('u2', name: 'Beta', host: 'two.example.com'),
      ]);
      await pumpPage(tester);
      expect(find.text('1'), findsNothing, reason: 'the query is not a filter');

      await tester.enterText(find.byType(SearchBar), 'beta');
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('1'), findsNothing, reason: 'the query is not a filter');
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsNothing);
    });
  });

  testWidgets('filters by category and tags from the drawer, then clears', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark(
          'u1',
          name: 'Alpha',
          host: 'one.example.com',
          category: ' Home ',
          tags: ['relay', 'shared'],
        ),
        testBookmark(
          'u2',
          name: 'Beta',
          host: 'two.example.com',
          category: 'Work',
          tags: ['relay', 'overseas'],
        ),
      ]);
      final controller = await pumpPage(tester);

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);
      expect(
        find.text('Narrow the bookmarks down by category or tag.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CheckboxListTile, 'Home'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, '#relay'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Home'));
      await tester.pumpAndSettle();
      expect(controller.category.value, 'Home');
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('1'), findsOneWidget, reason: 'the filter badge');

      await tester.tap(find.widgetWithText(CheckboxListTile, '#relay'));
      await tester.pumpAndSettle();
      expect(controller.tags.value, {'relay'});
      expect(find.text('2'), findsOneWidget, reason: 'the filter badge');

      // The category is single-select: another one replaces it.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
      await tester.pumpAndSettle();
      expect(controller.category.value, 'Work');
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      // Clearing from the drawer clears the search field's text too.
      controller.setQuery('beta');
      controller.searchController.text = 'beta';
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear filters'));
      await tester.pumpAndSettle();

      expect(controller.query.value, isEmpty);
      expect(controller.searchController.text, isEmpty);
      expect(controller.category.value, isNull);
      expect(controller.tags.value, isEmpty);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
    });
  });

  testWidgets('the drawer says when there is nothing to filter by', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();

      expect(
        find.text('No categories or tags yet. Edit a bookmark to add them.'),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  testWidgets('shows the no-results state and clears the filters', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(tester);

      await tester.enterText(find.byType(SearchBar), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks match'), findsOneWidget);
      expect(
        find.text('Try another search, or clear the filters.'),
        findsOneWidget,
      );
      expect(find.text('Shared Nodes'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('No bookmarks match'), findsNothing);
    });
  });

  testWidgets('adds a row to a saved network through the picker', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'peer.example.com'),
      ]);
      await seedNetworks();
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Add to Network'));
      await tester.pumpAndSettle();
      expect(find.text('Add to which network?'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);

      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      await settleStores();

      expect(find.text('Add to which network?'), findsNothing);
      expect((await persisted('n1')).nodes.single.id, 'u1');
      expect(messages.last, 'Added to alpha');
    });
  });

  testWidgets('the network picker explains that nothing is saved yet', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([testBookmark('u1', name: 'Alpha')]);
      await networks.init(temporaryStore());
      addTearDown(networks.dispose);
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Add to Network'));
      await tester.pumpAndSettle();

      expect(find.text('No saved networks yet'), findsOneWidget);
      expect(
        find.text('Create a network first, then add this node to it.'),
        findsOneWidget,
      );
      expect(find.text('alpha'), findsNothing);
    });
  });

  testWidgets('deletes a bookmark only after confirming', (tester) async {
    await tester.runAsync(() async {
      await seedBookmarks([testBookmark('u1', name: 'Alpha')]);
      final controller = await pumpPage(tester);

      await openMenu(tester, 'Alpha');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Alpha?'), findsOneWidget);
      expect(
        find.text(
          'It leaves this list only; networks that already use the node keep their peer.',
        ),
        findsOneWidget,
      );

      // A dismissal means no.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(persistedBookmarks().single.id, 'u1');

      await openMenu(tester, 'Alpha');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Deleting is destructive, so the confirm wears the theme's error pair.
      final confirm = find.widgetWithText(FilledButton, 'Delete');
      final button = tester.widget<FilledButton>(confirm);
      final scheme = Theme.of(tester.element(confirm)).colorScheme;
      expect(button.style?.backgroundColor?.resolve({}), scheme.error);
      expect(button.style?.foregroundColor?.resolve({}), scheme.onError);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await settleStores();

      expect(find.text('Alpha'), findsNothing);
      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(persistedBookmarks(), isEmpty);
      expect(controller.myBookmarks.value, isEmpty);
    });
  });

  testWidgets('no selection entry while the filters match nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'One', category: 'Home'),
      ]);
      await pumpPage(tester);
      expect(find.byTooltip(strings.selectionEnter), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'nothing matches this');
      await tester.pumpAndSettle();

      // Nothing is selectable, so the entry is gone, as on a filtered list of
      // networks.
      expect(find.text(strings.bookmarksNoResults), findsOneWidget);
      expect(find.byTooltip(strings.selectionEnter), findsNothing);
    });
  });

  testWidgets('offers every share channel and opens the sender for QR', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final clipboard = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        clipboard.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await seedBookmarks([
        testBookmark(
          'u1',
          name: 'Alpha',
          host: 'peer.example.com',
          port: 11010,
        ),
      ]);
      final exports = <String>[];
      await pumpPage(
        tester,
        saveExportFile: (name, content) async {
          exports.add(name);
          return true;
        },
      );

      await openShare(tester, 'Alpha');
      expect(find.text('Share Alpha'), findsOneWidget);
      expect(find.text('Send over network'), findsOneWidget);
      expect(find.text('Show QR code'), findsOneWidget);
      expect(find.text('Copy address'), findsOneWidget);
      expect(find.text('Export as JSON'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(M3EBottomSheet),
          matching: find.text('peer.example.com:11010'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Send over network'));
      await tester.pumpAndSettle();
      expect(find.text('Share Alpha'), findsNothing);
      expect(
        messages.last,
        'Sending over a network arrives with the data plane',
      );

      // The QR row pushes the sender over the list, carrying this bookmark.
      await openShare(tester, 'Alpha');
      await tester.tap(find.text('Show QR code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text('peer.example.com:11010'), findsOneWidget);
      expect(find.byType(BookmarksPage), findsNothing);

      // Back returns to the page that opened it.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(QrShareSendPage), findsNothing);
      expect(find.byType(BookmarksPage), findsOneWidget);

      await openShare(tester, 'Alpha');
      await tester.tap(find.text('Copy address'));
      await tester.pumpAndSettle();
      final copied = clipboard.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect((copied.arguments as Map)['text'], 'peer.example.com:11010');
      expect(messages.last, 'Copied peer.example.com:11010');

      await openShare(tester, 'Alpha');
      await tester.tap(find.text('Export as JSON'));
      await tester.pumpAndSettle();
      await settleStores();
      expect(exports.single, 'yukari-bookmarks.json');
      expect(messages.last, 'Bookmarks exported');

      // Unmounting disposes the sender page and its paused controller.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a tap on a row in selection toggles it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'One'),
        testBookmark('u2', name: 'Two', host: 'other.example.com'),
      ]);
      final controller = await pumpPage(tester);

      await tester.tap(find.byTooltip(strings.selectionEnter));
      await tester.pumpAndSettle();
      expect(controller.selection.selecting.value, isTrue);

      // The actions make way for the check, which rides the trailing slot of
      // each row like it does on a network card.
      expect(find.byTooltip('More options for One'), findsNothing);
      expect(find.byTooltip(strings.bookmarksAddToNetwork), findsNothing);
      expect(find.byType(SelectionCheck), findsNWidgets(2));

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing, reason: 'the row toggles');
      expect(controller.selection.ids.value, {'u1'});
      final checks = tester
          .widgetList<SelectionCheck>(find.byType(SelectionCheck))
          .toList();
      expect(checks.map((check) => check.selected), [true, false]);
      expect(find.text(strings.selectionSelected(1)), findsOneWidget);

      // The check sits on its row's centre line, the same place the network
      // card puts it.
      final item = tester.getCenter(
        find.ancestor(
          of: find.text('One'),
          matching: find.byType(M3EListItem),
        ),
      );
      expect(
        tester.getCenter(find.byType(SelectionCheck).first).dy,
        closeTo(item.dy, 0.5),
      );
    });
  });

  testWidgets('the selection shares its nodes as one bundle', (tester) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'One'),
        testBookmark('u2', name: 'Two', host: 'other.example.com'),
      ]);
      final controller = await pumpPage(tester);

      await tester.tap(find.byTooltip(strings.selectionEnter));
      await tester.pumpAndSettle();
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text(strings.selectionSelected(2)), findsOneWidget);

      await tester.tap(find.text(strings.selectionShare));
      await tester.pumpAndSettle();

      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text(strings.shareItems(2)), findsOneWidget);
      // The sender is what the user asked for, so the list stops selecting.
      expect(controller.selection.selecting.value, isFalse);
    });
  });

  testWidgets('leaving selection restores the search bar and the menu', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([testBookmark('u1', name: 'One')]);
      await pumpPage(tester);

      expect(find.byType(SearchBar), findsOneWidget);
      await tester.tap(find.byTooltip(strings.selectionEnter));
      await tester.pumpAndSettle();

      expect(find.byType(SearchBar), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      await tester.tap(find.byTooltip(strings.selectionExit));
      await tester.pumpAndSettle();

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  testWidgets('offers add, import and scan from the action menu', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(
        tester,
        pickImportFile: () async => encodeBookmarks(
          BookmarkDocument(
            bookmarks: [testBookmark('i1', host: 'two.example.com')],
          ),
        ),
      );

      await openFabMenu(tester);
      expect(find.text('Add Bookmark'), findsOneWidget);
      expect(find.text('Import from file'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);

      await tester.tap(find.text('Add Bookmark'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await openFabMenu(tester);
      await tester.tap(find.text('Import from file'));
      await tester.pumpAndSettle();
      await settleStores();

      expect(messages.last, 'Imported 1 bookmarks');
      expect(
        persistedBookmarks().map((bookmark) => bookmark.id),
        contains('i1'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the action menu scans a share in from another device', (
    tester,
  ) async {
    // The receiver builds the camera widget on the target platform the test
    // binding reports (android); this platform scans the picked image instead.
    // The override is reset before the test returns, as the binding checks that
    // no foundation debug variable was left changed.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.runAsync(() async {
        await seedBookmarks();
        await pumpPage(tester);

        await openFabMenu(tester);
        await tester.tap(find.text('Scan QR Code'));
        // The receiver's indeterminate progress animates until the first
        // frame, so bound the frames instead of waiting for stillness.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(QrShareReceivePage), findsOneWidget);
        expect(find.byType(BookmarksPage), findsNothing);

        // Back returns to the page that opened it.
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(QrShareReceivePage), findsNothing);
        expect(find.byType(BookmarksPage), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('disables the export action until a bookmark is saved', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks();
      final controller = await pumpPage(
        tester,
        builtins: [testBookmark('builtin:one', name: 'Shared One')],
      );
      IconButton exportButton() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.file_download_outlined),
      );

      expect(
        exportButton().onPressed,
        isNull,
        reason: 'built-ins do not count',
      );

      await controller.add(
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      );
      await tester.pumpAndSettle();
      await settleStores();

      expect(exportButton().onPressed, isNotNull);
    });
  });

  testWidgets('typing rebuilds the list, not the bar or the menu', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark('u1', name: 'Alpha', host: 'one.example.com'),
      ]);
      await pumpPage(tester);

      final bar = tester.widget(find.byType(SearchBar));
      final menu = tester.widget(find.byType(M3EFabMenu));
      final row = tester.widget(find.text('Alpha'));

      await tester.enterText(find.byType(SearchBar), 'alp');
      await tester.pumpAndSettle();

      expect(
        identical(tester.widget(find.byType(SearchBar)), bar),
        isTrue,
        reason: 'the field the user types in must not rebuild',
      );
      expect(
        identical(tester.widget(find.byType(M3EFabMenu)), menu),
        isTrue,
        reason: 'the action menu does not depend on the query',
      );
      expect(
        identical(tester.widget(find.text('Alpha')), row),
        isFalse,
        reason: 'the filtered row must rebuild',
      );
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });
  });

  testWidgets('a filter change rebuilds the badge and the rows only', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedBookmarks([
        testBookmark(
          'u1',
          name: 'Alpha',
          host: 'one.example.com',
          category: 'Work',
        ),
      ]);
      final controller = await pumpPage(tester);
      final bar = tester.widget(find.byType(SearchBar));
      final menu = tester.widget(find.byType(M3EFabMenu));
      final row = tester.widget(find.text('Alpha'));

      controller.toggleCategory('Work');
      await tester.pumpAndSettle();

      expect(
        identical(tester.widget(find.byType(SearchBar)), bar),
        isTrue,
        reason: 'the search bar does not depend on the filters',
      );
      expect(
        identical(tester.widget(find.byType(M3EFabMenu)), menu),
        isTrue,
        reason: 'the action menu does not depend on the filters',
      );
      expect(find.text('1'), findsOneWidget, reason: 'the filter badge');
      expect(
        identical(tester.widget(find.text('Alpha')), row),
        isFalse,
        reason: 'the filtered row must rebuild',
      );
    });
  });
}

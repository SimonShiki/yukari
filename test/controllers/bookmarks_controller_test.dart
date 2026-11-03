import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/controllers/bookmarks_actions.dart';
import 'package:yukari/controllers/bookmarks_controller.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';
import 'package:yukari/signals/bookmarks.dart' as saved;
import 'package:yukari/utils/bookmark_codec.dart';

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';

/// A lowercase v4 UUID, as [BookmarksActions.compose] generates.
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> messages;

  setUp(() => messages = []);

  BookmarksController controllerFor({
    List<Bookmark>? builtins,
    BookmarkFilePicker? pickImportFile,
    BookmarkFileSaver? saveExportFile,
  }) {
    final controller = BookmarksController(
      showMessage: messages.add,
      builtins: builtins,
      pickImportFile: pickImportFile,
      saveExportFile: saveExportFile,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  List<String> ids(Iterable<Bookmark> bookmarks) => [
    for (final bookmark in bookmarks) bookmark.id,
  ];

  group('filtering', () {
    test('matches the category, then every tag, then the query', () async {
      await seedBookmarks([
        testBookmark('a', name: 'Alpha', category: ' Home ', tags: ['relay']),
        testBookmark('b', name: 'Beta', category: 'Work', tags: ['relay']),
        testBookmark('c', name: 'Gamma', category: 'Home', tags: ['overseas']),
      ]);
      final controller = controllerFor(builtins: []);

      // ' Home ' is the same category as 'Home' everywhere.
      controller.toggleCategory('Home');
      expect(ids(controller.visibleBookmarks.value), ['a', 'c']);

      controller.toggleTag('relay');
      expect(ids(controller.visibleBookmarks.value), ['a']);

      controller.setQuery('gamma');
      expect(controller.visibleBookmarks.value, isEmpty);

      controller.setQuery('ALPHA');
      expect(ids(controller.visibleBookmarks.value), ['a']);
    });

    test('searches name, address, category, description and tags', () async {
      await seedBookmarks([
        testBookmark('a', host: 'one.example.com', name: 'Alpha'),
        testBookmark(
          'b',
          host: 'two.example.com',
          description: 'a fast relay',
          name: 'Beta',
        ),
        testBookmark(
          'c',
          host: 'three.example.com',
          category: 'Home',
          name: 'Gamma',
        ),
        testBookmark(
          'd',
          host: 'four.example.com',
          tags: ['overseas'],
          name: 'Delta',
        ),
      ]);
      final controller = controllerFor(builtins: []);

      for (final (query, expected) in [
        ('one.example', ['a']),
        ('fast', ['b']),
        ('home', ['c']),
        ('overseas', ['d']),
      ]) {
        controller.setQuery(query);
        expect(ids(controller.visibleBookmarks.value), expected, reason: query);
      }
    });

    test(
      'inventories the trimmed categories and tags, built-ins included',
      () async {
        await seedBookmarks([
          testBookmark('u1', category: 'Home', tags: ['relay', 'home']),
          testBookmark('u2', category: '  ', tags: ['relay']),
        ]);
        final controller = controllerFor(
          builtins: [
            testBookmark('builtin:x', category: ' Shared ', tags: [' relay ']),
          ],
        );

        expect(controller.categoryOptions.value, ['Home', 'Shared']);
        expect(controller.tagOptions.value, ['home', 'relay']);
      },
    );

    test('lists the built-ins first, then the saved bookmarks', () async {
      await seedBookmarks([
        testBookmark('u1', name: 'One'),
        testBookmark('u2', name: 'Two'),
      ]);
      final controller = controllerFor(
        builtins: [testBookmark('builtin:a', name: 'Shared')],
      );

      expect(ids(controller.allBookmarks.value), ['builtin:a', 'u1', 'u2']);
      expect(ids(controller.sharedBookmarks.value), ['builtin:a']);
      expect(ids(controller.myBookmarks.value), ['u1', 'u2']);
    });

    test('counts the filters but not the query in the badge', () async {
      await seedBookmarks([
        testBookmark('u1', category: 'Home', tags: ['a']),
      ]);
      final controller = controllerFor(builtins: []);

      expect(controller.activeFilterCount.value, 0);
      controller.setQuery('anything');
      expect(controller.activeFilterCount.value, 0);

      controller.toggleCategory('Home');
      controller.toggleTag('a');
      expect(controller.activeFilterCount.value, 2);

      controller.toggleCategory('Home');
      expect(controller.activeFilterCount.value, 1);
      controller.toggleTag('a');
      expect(controller.activeFilterCount.value, 0);
    });

    test('clearFilters clears the search field and every filter', () async {
      await seedBookmarks([
        testBookmark('u1', category: 'Home', tags: ['a']),
      ]);
      final controller = controllerFor(builtins: []);
      controller.setQuery('ab');
      controller.searchController.text = 'ab';
      controller.toggleCategory('Home');
      controller.toggleTag('a');

      controller.clearFilters();

      expect(controller.query.value, isEmpty);
      expect(controller.searchController.text, isEmpty);
      expect(controller.category.value, isNull);
      expect(controller.tags.value, isEmpty);
      expect(controller.activeFilterCount.value, 0);
    });

    test('clearQuery clears the search field without the filters', () async {
      await seedBookmarks([testBookmark('u1', category: 'Home')]);
      final controller = controllerFor(builtins: []);
      controller.setQuery('ab');
      controller.searchController.text = 'ab';
      controller.toggleCategory('Home');

      controller.clearQuery();

      expect(controller.query.value, isEmpty);
      expect(controller.searchController.text, isEmpty);
      expect(controller.category.value, 'Home');
    });

    test('knows when there is anything at all and when it matches', () async {
      await seedBookmarks();
      final controller = controllerFor(builtins: []);
      expect(controller.hasBookmarks.value, isFalse);
      expect(controller.hasMatches.value, isFalse);

      await controller.add(testBookmark('u1', name: 'One'));
      expect(controller.hasBookmarks.value, isTrue);
      expect(controller.hasMatches.value, isTrue);

      controller.setQuery('nope');
      expect(controller.hasBookmarks.value, isTrue);
      expect(controller.hasMatches.value, isFalse);
    });
  });

  group('mutations', () {
    test('adds, updates and deletes through the store', () async {
      await seedBookmarks();
      final controller = controllerFor(builtins: []);
      final bookmark = testBookmark('u1', name: 'One');

      expect(await controller.add(bookmark), isTrue);
      expect(persistedBookmarks().single.id, 'u1');

      bookmark.name = 'Renamed';
      expect(await controller.update(bookmark), isTrue);
      expect(persistedBookmarks().single.name, 'Renamed');

      expect(await controller.delete(bookmark), isTrue);
      expect(persistedBookmarks(), isEmpty);
      expect(messages, isEmpty, reason: 'successful writes say nothing');
    });

    test('reports a failed write instead of throwing', () async {
      await seedBookmarks([testBookmark('u1')]);
      final controller = controllerFor(builtins: []);
      await saved.dispose();

      expect(await controller.add(testBookmark('u2')), isFalse);
      expect(messages.last, startsWith('Could not save the bookmark:'));
      expect(await controller.delete(testBookmark('u1')), isFalse);
      expect(messages.last, startsWith('Could not delete the bookmark:'));
    });

    test('deletes the whole selection, then leaves it', () async {
      await seedBookmarks([
        testBookmark('u1', name: 'One'),
        testBookmark('u2', name: 'Two'),
        testBookmark('u3', name: 'Three'),
      ]);
      final controller = controllerFor(builtins: []);
      controller.selection
        ..enter()
        ..select(['u1', 'u3']);

      expect(ids(controller.selectedBookmarks.value), ['u1', 'u3']);

      await controller.deleteSelection();

      expect(ids(persistedBookmarks()), ['u2']);
      expect(controller.selection.selecting.value, isFalse);
      expect(messages, isEmpty, reason: 'a batch delete says nothing');
    });

    test('a selection of built-in nodes deletes nothing', () async {
      await seedBookmarks([testBookmark('u1')]);
      final builtin = builtinBookmarks.first;
      final controller = controllerFor(builtins: [builtin]);
      controller.selection
        ..enter()
        ..select([builtin.id]);

      // The shared nodes are shareable but not the store's to delete.
      expect(controller.selectedBookmarks.value, isEmpty);

      await controller.deleteSelection();

      expect(ids(persistedBookmarks()), ['u1']);
      expect(controller.selection.selecting.value, isTrue);
      expect(messages, isEmpty);
    });

    test('reports a selection delete the store refuses once', () async {
      await seedBookmarks([testBookmark('u1'), testBookmark('u2')]);
      final controller = controllerFor(builtins: []);
      controller.selection
        ..enter()
        ..select(['u1', 'u2']);
      await saved.dispose();

      await controller.deleteSelection();

      // A batch reports through its own wording, once, not per bookmark.
      expect(
        messages.single,
        startsWith('Could not delete the selected bookmarks:'),
      );
      expect(controller.selection.selecting.value, isFalse);
    });

    test('disposing during a batch delete writes no disposed signal', () async {
      await seedBookmarks([testBookmark('u1'), testBookmark('u2')]);
      // Built here, not with [controllerFor]: this test disposes it by hand.
      final controller = BookmarksController(
        showMessage: messages.add,
        builtins: const [],
      );
      controller.selection
        ..enter()
        ..select(['u1', 'u2']);

      final pending = controller.deleteSelection();
      controller.dispose();

      // Without the guard the batch ends by writing a disposed selection.
      await expectLater(pending, completes);
      expect(ids(persistedBookmarks()), isEmpty, reason: 'the batch landed');
    });

    test('composes a new bookmark with a v4 id and blank fields as null', () {
      final controller = controllerFor(builtins: []);
      final node = Node(
        id: 'peer',
        url: Uri.parse('peer.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      );

      final bookmark = controller.compose(
        draft: (
          node: node,
          name: '  ',
          description: '',
          category: ' ',
          tags: ' a, b ,a, ,c ',
        ),
      );

      expect(_uuidV4.hasMatch(bookmark.id), isTrue, reason: bookmark.id);
      expect(bookmark.name, isNull);
      expect(bookmark.description, isNull);
      expect(bookmark.category, isNull);
      expect(bookmark.tags, ['a', 'b', 'c']);
      expect(bookmark.createdAt.isUtc, isTrue);
      expect(bookmark.updatedAt.isUtc, isTrue);
    });

    test('an edit keeps its identity and stamps a new update time', () async {
      final created = DateTime.utc(2020);
      final existing = Bookmark(
        id: 'u1',
        node: Node(
          id: 'old',
          url: Uri.parse('old.example.com'),
          port: 11010,
          protocols: const [NodeProtocol.tcp],
        ),
        createdAt: created,
        updatedAt: created,
        extensions: const {'acme': 1},
      );
      await seedBookmarks([existing]);
      final controller = controllerFor(builtins: []);
      final before = DateTime.now().toUtc();

      final saved = await controller.save(
        existing: existing,
        draft: (
          node: Node(
            id: 'new',
            url: Uri.parse('new.example.com'),
            port: 12010,
            protocols: const [NodeProtocol.udp],
          ),
          name: '  Name  ',
          description: ' A description ',
          category: ' Home ',
          tags: 'relay, relay',
        ),
      );

      expect(saved, isTrue);
      final edited = persistedBookmarks().single;
      expect(edited.id, 'u1');
      expect(edited.name, 'Name');
      expect(edited.description, 'A description');
      expect(edited.category, 'Home');
      expect(edited.tags, ['relay']);
      expect(edited.createdAt, created);
      expect(edited.extensions, {'acme': 1});
      expect(edited.updatedAt.isBefore(before), isFalse);
    });
  });

  group('networks', () {
    test('reports which networks hold the node', () async {
      await seedBookmarks([testBookmark('u1', host: 'peer.example.com')]);
      await seedNetworks();
      final controller = controllerFor(builtins: []);
      final bookmark = saved.bookmarks.value.single;

      expect(controller.networkOptions(bookmark), [
        (id: 'n1', name: 'alpha', contains: false),
        (id: 'n2', name: 'beta', contains: false),
      ]);

      await controller.addToNetwork(bookmark, 'n1');
      expect(controller.networkOptions(bookmark).first.contains, isTrue);
    });

    test('appends a copy of the node and reports the added network', () async {
      await seedBookmarks([testBookmark('u1', host: 'peer.example.com')]);
      await seedNetworks();
      final controller = controllerFor(builtins: []);
      final bookmark = saved.bookmarks.value.single;

      await controller.addToNetwork(bookmark, 'n1');

      expect(messages.single, 'Added to alpha');
      expect((await persisted('n1')).nodes.single.id, 'u1');

      // The stored node is a copy: editing the bookmark afterwards is free.
      bookmark.node.id = 'changed';
      expect((await persisted('n1')).nodes.single.id, 'u1');
    });

    test('reports a node the network already has', () async {
      await seedBookmarks([testBookmark('u1', host: 'peer.example.com')]);
      await seedNetworks();
      final controller = controllerFor(builtins: []);
      final bookmark = saved.bookmarks.value.single;

      await controller.addToNetwork(bookmark, 'n1');
      await controller.addToNetwork(bookmark, 'n1');

      expect(messages.last, 'Already in alpha');
      expect((await persisted('n1')).nodes.length, 1);
    });

    test('an unknown network does nothing at all', () async {
      await seedBookmarks([testBookmark('u1')]);
      await seedNetworks();
      final controller = controllerFor(builtins: []);

      await controller.addToNetwork(saved.bookmarks.value.single, 'missing');

      expect(messages, isEmpty);
      expect((await persisted('n1')).nodes, isEmpty);
      expect((await persisted('n2')).nodes, isEmpty);
    });
  });

  group('file round trip', () {
    test('exports every saved bookmark whatever the filters show', () async {
      await seedBookmarks([
        testBookmark('u1', name: 'One', category: 'Home'),
        testBookmark('u2', name: 'Two', category: 'Work'),
      ]);
      final writes = <(String, String)>[];
      final controller = controllerFor(
        builtins: [],
        saveExportFile: (name, content) async {
          writes.add((name, content));
          return true;
        },
      );
      controller.toggleCategory('Home');

      await controller.exportToFile();

      expect(writes.single.$1, 'yukari-bookmarks.json');
      expect(ids(decodeBookmarks(writes.single.$2).bookmarks), ['u1', 'u2']);
      expect(messages.single, 'Bookmarks exported');
    });

    test('a cancelled export says nothing', () async {
      await seedBookmarks([testBookmark('u1')]);
      final controller = controllerFor(
        builtins: [],
        saveExportFile: (_, _) async => false,
      );

      await controller.exportToFile();

      expect(messages, isEmpty);
    });

    test('a failed export is reported', () async {
      await seedBookmarks([testBookmark('u1')]);
      final controller = controllerFor(
        builtins: [],
        saveExportFile: (_, _) async => throw StateError('disk full'),
      );

      await controller.exportToFile();

      expect(messages.single, startsWith('Export failed:'));
    });

    test('exports nothing while only built-ins exist', () async {
      await seedBookmarks();
      final written = <String>[];
      final controller = controllerFor(
        builtins: [testBookmark('builtin:a')],
        saveExportFile: (name, _) async {
          written.add(name);
          return true;
        },
      );

      expect(controller.canExport.value, isFalse);
      await controller.add(testBookmark('u1'));
      expect(controller.canExport.value, isTrue);
    });

    test('imports new bookmarks, their count and their extensions', () async {
      await seedBookmarks();
      final document = BookmarkDocument(
        bookmarks: [
          testBookmark('i1', host: 'one.example.com'),
          testBookmark('i2', host: 'two.example.com'),
        ],
        extensions: const {'acme': 1},
      );
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async => encodeBookmarks(document),
      );

      await controller.importFromFile();

      expect(messages.single, 'Imported 2 bookmarks');
      expect(ids(persistedBookmarks()), ['i1', 'i2']);
      expect(persistedDocument().extensions, {'acme': 1});
    });

    test('reports a file with nothing new', () async {
      await seedBookmarks([testBookmark('u1')]);
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async =>
            encodeBookmarks(BookmarkDocument(bookmarks: [testBookmark('u1')])),
      );

      await controller.importFromFile();

      expect(messages.single, 'Nothing new to import');
    });

    test('reports an unreadable file', () async {
      await seedBookmarks();
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async => throw const FormatException('gone'),
      );

      await controller.importFromFile();

      expect(messages.single, 'That file cannot be read');
    });

    test('a dismissed picker says nothing', () async {
      await seedBookmarks();
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async => null,
      );

      await controller.importFromFile();

      expect(messages, isEmpty);
    });

    test('reports an invalid document', () async {
      await seedBookmarks();
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async => 'not a bookmarks document',
      );

      await controller.importFromFile();

      expect(messages.single, startsWith('Not a valid bookmarks file:'));
    });

    test('reports an import the store refused', () async {
      await seedBookmarks();
      final controller = controllerFor(
        builtins: [],
        pickImportFile: () async =>
            encodeBookmarks(BookmarkDocument(bookmarks: [testBookmark('i1')])),
      );
      await saved.dispose();

      await controller.importFromFile();

      expect(messages.single, startsWith('Import failed:'));
    });
  });

  group('sharing', () {
    test('copies the address and reports it', () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await seedBookmarks();
      final controller = controllerFor(builtins: []);

      await controller.copyAddress(
        testBookmark('u1', host: 'peer.example.com', port: 11010),
      );

      expect(calls.single.method, 'Clipboard.setData');
      expect((calls.single.arguments as Map)['text'], 'peer.example.com:11010');
      expect(messages.single, 'Copied peer.example.com:11010');
    });

    test('reports the share channel that is not implemented', () {
      final controller = controllerFor(builtins: []);

      controller.shareOverNetwork();

      expect(messages, ['Sending over a network arrives with the data plane']);
    });
  });

  test('the real shared nodes are inventoried and never exported', () async {
    await seedBookmarks();
    final controller = controllerFor();

    expect(controller.canExport.value, isFalse);
    expect(controller.allBookmarks.value.length, builtinBookmarks.length);
    expect(controller.categoryOptions.value, contains(sharedNodeCategory));
    expect(
      controller.tagOptions.value,
      containsAll([sharedNodeRelayTag, sharedNodeOverseasTag]),
    );
    expect(
      controller.sharedBookmarks.value.map((bookmark) => bookmark.id),
      builtinBookmarks.map((bookmark) => bookmark.id),
    );
    expect(controller.myBookmarks.value, isEmpty);
  });

  group('selection', () {
    test('what can be selected follows the filters', () async {
      await seedBookmarks([
        testBookmark('a', name: 'Alpha', category: 'Home'),
        testBookmark('b', name: 'Beta', category: 'Work'),
      ]);
      final controller = controllerFor(builtins: []);
      expect(controller.selectableIds.value, ['a', 'b']);

      controller.toggleCategory('Work');
      expect(controller.selectableIds.value, ['b']);

      // Select all means all of what the page shows.
      controller.selection
        ..enter()
        ..toggleAll();
      expect(controller.selection.ids.value, {'b'});
      expect(controller.selection.count.value, 1);
    });

    test('sharing a selection builds one bundle path and leaves it', () async {
      await seedBookmarks([
        testBookmark('a', name: 'Alpha'),
        testBookmark('b', name: 'Beta', host: 'other.example.com'),
      ]);
      final controller = controllerFor(builtins: []);
      controller.selection
        ..enter()
        ..select(['b', 'a']);

      expect(
        controller.selectionShareRoute(),
        shareSendPaths(ShareKind.node, ['a', 'b']),
      );
      expect(controller.selection.selecting.value, isFalse);
      expect(controller.selection.ids.value, isEmpty);
    });

    test('a selection with a node that cannot be shared reports it', () async {
      await seedBookmarks([
        testBookmark('a', name: 'Alpha'),
        // A node that needs credentials cannot be shared as it is.
        testBookmark('b', name: 'Beta', host: 'https://u:p@relay.example.com'),
      ]);
      final controller = controllerFor(builtins: []);
      controller.selection
        ..enter()
        ..select(['a', 'b']);

      expect(controller.selectionShareRoute(), isNull);
      expect(messages, [
        lookupAppLocalizations(const Locale('en')).selectionUnavailable(1),
      ]);
      // Nothing was shared, so the selection stays for the user to fix.
      expect(controller.selection.selecting.value, isTrue);
      expect(controller.selection.ids.value, {'a', 'b'});
    });
  });

  test('dispose disposes the signals it created', () {
    final controller = BookmarksController(showMessage: messages.add);
    controller.hasBookmarks.value;
    controller.activeFilterCount.value;

    controller.dispose();

    expect(controller.query.disposed, isTrue);
    expect(controller.hasBookmarks.disposed, isTrue);
    expect(controller.activeFilterCount.disposed, isTrue);
  });
}

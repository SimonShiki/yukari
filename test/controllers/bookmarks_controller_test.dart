import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';
import 'package:yukari/controllers/bookmarks_controller.dart';
import 'package:yukari/models/node.dart';
import 'package:yukari/signals/networks.dart';

import '../bookmarks_fixture.dart';
import '../networks_fixture.dart';

void main() {
  test('narrows the list by search text, category and tags', () async {
    await seedBookmarks([
      testBookmark(
        'b1',
        host: 'relay.example.com',
        name: 'Home relay',
        category: 'Home',
        tags: const ['fast', 'tcp'],
      ),
      testBookmark(
        'b2',
        host: 'public.example.com',
        name: 'Public relay',
        category: 'Public',
        tags: const ['fast'],
      ),
      testBookmark(
        'b3',
        host: 'office.example.com',
        description: 'the office box',
      ),
    ]);
    final controller = BookmarksController(showMessage: (_) {});
    addTearDown(controller.dispose);

    final builtinIds = [for (final bookmark in builtinBookmarks) bookmark.id];
    expect(controller.visible.value.map((bookmark) => bookmark.id), [
      ...builtinIds,
      'b1',
      'b2',
      'b3',
    ]);
    expect(controller.filtered, isFalse);

    controller.query.value = 'office';
    expect(controller.visible.value.map((bookmark) => bookmark.id), ['b3']);

    controller.query.value = 'fast';
    expect(controller.visible.value.map((bookmark) => bookmark.id), [
      'b1',
      'b2',
    ]);

    controller.query.value = '';
    controller.category.value = 'Home';
    expect(controller.visible.value.map((bookmark) => bookmark.id), ['b1']);

    controller.category.value = null;
    controller.toggleTag('fast');
    expect(controller.visible.value.map((bookmark) => bookmark.id), [
      'b1',
      'b2',
    ]);

    controller.clearFilters();
    expect(controller.filtered, isFalse);
    expect(controller.visible.value.length, builtinIds.length + 3);
  });

  test('lists the categories and tags in use', () async {
    await seedBookmarks([
      testBookmark('b1', category: 'Home', tags: const ['tcp', 'fast']),
      testBookmark('b2', category: 'Public', tags: const ['fast']),
      testBookmark('b3', category: '  '),
    ]);
    final controller = BookmarksController(showMessage: (_) {});
    addTearDown(controller.dispose);

    // The built-in shared nodes contribute their own category and tags.
    expect(controller.categories.value, ['Home', 'Public', sharedNodeCategory]);
    expect(controller.availableTags.value, [
      'fast',
      sharedNodeOverseasTag,
      sharedNodeRelayTag,
      'tcp',
    ]);
  });

  test('shows built-in shared nodes before the saved ones', () async {
    await seedBookmarks([testBookmark('b1', host: 'mine.example.com')]);
    final controller = BookmarksController(
      showMessage: (_) {},
      builtins: [testBookmark('builtin:shared', host: 'shared.example.com')],
    );
    addTearDown(controller.dispose);

    expect(controller.all.value.map((bookmark) => bookmark.id), [
      'builtin:shared',
      'b1',
    ]);
    expect(nodeHost(controller.builtins.single.node.url), 'shared.example.com');
  });

  test('adds a bookmark to a network, once', () async {
    await seedNetworks();
    await seedBookmarks();
    final messages = <String>[];
    final controller = BookmarksController(showMessage: messages.add);
    addTearDown(controller.dispose);

    final bookmark = testBookmark('b1', host: 'relay.example.com');
    await controller.addToNetwork(bookmark, 'n1');

    expect(networks.value['n1']!.nodes.single.id, 'b1');
    expect(
      nodeHost(networks.value['n1']!.nodes.single.url),
      'relay.example.com',
    );
    expect(messages, ['Added to alpha']);

    await controller.addToNetwork(bookmark, 'n1');

    expect(networks.value['n1']!.nodes.length, 1);
    expect(messages.last, 'Already in alpha');
  });
}

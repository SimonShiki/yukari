import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/signals/bookmarks.dart';

import '../bookmarks_fixture.dart';

void main() {
  test('adds, updates and deletes bookmarks through the store', () async {
    await seedBookmarks();

    await addBookmark(testBookmark('b1', name: 'Relay'));
    await settled();
    expect(bookmarks.value.single.name, 'Relay');
    expect(persistedBookmarks().single.id, 'b1');

    await updateBookmark(testBookmark('b1', name: 'Renamed'));
    await settled();
    expect(bookmarks.value.single.name, 'Renamed');
    expect(persistedBookmarks().single.name, 'Renamed');

    await deleteBookmark('b1');
    await settled();
    expect(bookmarks.value, isEmpty);
    expect(persistedBookmarks(), isEmpty);
  });

  test('refuses a duplicate id and an update of a missing bookmark', () async {
    await seedBookmarks([testBookmark('b1')]);

    await expectLater(addBookmark(testBookmark('b1')), throwsStateError);
    await expectLater(updateBookmark(testBookmark('b2')), throwsStateError);
  });

  test('merging skips ids and addresses already saved', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com'),
      testBookmark('b2', host: 'other.example.com'),
    ]);

    final added = await addBookmarks([
      testBookmark('b1'), // same id
      testBookmark('b3', host: 'relay.example.com'), // same address
      testBookmark('b4', host: 'new.example.com'),
    ]);
    await settled();

    expect(added, 1);
    expect(bookmarks.value.map((bookmark) => bookmark.id), ['b1', 'b2', 'b4']);
    expect(persistedBookmarks().length, 3);
  });

  test('merging keeps imported extensions for the next export', () async {
    await seedBookmarks();

    await addBookmarks([testBookmark('b1')], extensions: const {'acme': 1});
    await settled();

    expect(bookmarkExtensions.value, {'acme': 1});
    expect(persistedDocument().extensions, {'acme': 1});
  });

  test('finds the saved bookmark for an address', () async {
    await seedBookmarks([
      testBookmark('b1', host: 'relay.example.com', port: 11010),
    ]);

    expect(
      bookmarkFor(testBookmark('x', host: 'relay.example.com').node)?.id,
      'b1',
    );
    expect(
      bookmarkFor(
        testBookmark('x', host: 'relay.example.com', port: 12010).node,
      ),
      isNull,
    );
  });
}

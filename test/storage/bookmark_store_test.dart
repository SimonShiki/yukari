import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/storage/bookmark_store.dart';
import 'package:yukari/utils/bookmark_codec.dart';

import '../bookmarks_fixture.dart';

void main() {
  test('saves and loads bookmarks in order', () async {
    final store = temporaryBookmarkStore();
    await store.save(
      BookmarkDocument(
        bookmarks: [
          testBookmark('b1'),
          testBookmark('b2', name: 'Beta'),
        ],
      ),
    );

    final loaded = await BookmarkStore(store.file).load();

    expect(loaded.bookmarks.map((bookmark) => bookmark.id), ['b1', 'b2']);
    expect(loaded.bookmarks.last.name, 'Beta');
  });

  test('a missing file holds no bookmarks', () async {
    final loaded = await temporaryBookmarkStore().load();

    expect(loaded.bookmarks, isEmpty);
  });

  test('keeps the custom extensions an import brought in', () async {
    final store = temporaryBookmarkStore();
    await store.save(
      BookmarkDocument(
        bookmarks: [testBookmark('b1')],
        extensions: const {'source': 'acme'},
      ),
    );

    final loaded = await BookmarkStore(store.file).load();

    expect(loaded.extensions, {'source': 'acme'});
  });

  test('a malformed file is refused', () async {
    final store = temporaryBookmarkStore();
    await store.file.writeAsString('{"bookmarks": "nope"}');

    expect(store.load, throwsFormatException);
  });
}

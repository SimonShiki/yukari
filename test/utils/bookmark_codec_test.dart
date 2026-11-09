import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/utils/bookmark_codec.dart';

import '../bookmarks_fixture.dart';

void main() {
  test('round-trips bookmarks and their extensions', () {
    final bookmark = testBookmark(
      'b1',
      name: 'Relay',
      category: 'Public',
      tags: const ['fast'],
    );
    bookmark.extensions = const {'vendor': 'acme'};

    final encoded = encodeBookmarks(
      BookmarkDocument(
        bookmarks: [bookmark],
        exportedAt: DateTime.utc(2026, 5, 6),
        extensions: const {'source': 'another-tool'},
      ),
    );
    final decoded = decodeBookmarks(encoded);

    expect(decoded.bookmarks.single.id, 'b1');
    expect(decoded.bookmarks.single.extensions, {'vendor': 'acme'});
    expect(decoded.exportedAt, DateTime.utc(2026, 5, 6));
    expect(decoded.extensions, {'source': 'another-tool'});
  });

  test('reads a bare array of bookmarks', () {
    final decoded = decodeBookmarks(
      jsonEncode([
        testBookmark('b1').toJson(),
        testBookmark('b2', host: 'other.example.com').toJson(),
      ]),
    );

    expect(decoded.bookmarks.map((bookmark) => bookmark.id), ['b1', 'b2']);
    expect(decoded.extensions, isEmpty);
  });

  test('keeps unknown top-level keys as extensions', () {
    final decoded = decodeBookmarks(
      jsonEncode({
        'version': 1,
        'bookmarks': <Object?>[],
        'generatedBy': 'acme-tool',
        'extensions': {'note': 'hello'},
      }),
    );

    expect(decoded.extensions, {'generatedBy': 'acme-tool', 'note': 'hello'});
  });

  test('gives an entry without timestamps one', () {
    final json = testBookmark('b1').toJson()
      ..remove('createdAt')
      ..remove('updatedAt');

    final bookmark = decodeBookmarks(
      jsonEncode({
        'bookmarks': [json],
      }),
    ).bookmarks.single;

    expect(bookmark.createdAt, isNotNull);
    expect(bookmark.updatedAt, isNotNull);
  });

  test('refuses malformed documents instead of loading half of them', () {
    final valid = testBookmark('b1').toJson();

    final invalid = <String, String>{
      'not JSON': 'nope',
      'not an object': '42',
      'no bookmarks list': jsonEncode({'version': 1}),
      'entry is not an object': jsonEncode({
        'bookmarks': ['nope'],
      }),
      'entry without an id': jsonEncode({
        'bookmarks': [
          {...valid, 'id': ' '},
        ],
      }),
      'entry without an address': jsonEncode({
        'bookmarks': [
          {
            ...valid,
            'node': {...valid['node']! as Map, 'url': ''},
          },
        ],
      }),
      'entry with a bad port': jsonEncode({
        'bookmarks': [
          {
            ...valid,
            'node': {
              ...valid['node']! as Map,
              'url': 'tcp://example.com:70000',
            },
          },
        ],
      }),
      'entry without protocols': jsonEncode({
        'bookmarks': [
          {
            ...valid,
            'node': {...valid['node']! as Map, 'protocols': <Object?>[]},
          },
        ],
      }),
      'a newer version': jsonEncode({
        'version': bookmarkDocumentVersion + 1,
        'bookmarks': <Object?>[],
      }),
    };

    invalid.forEach((description, content) {
      expect(
        () => decodeBookmarks(content),
        throwsFormatException,
        reason: description,
      );
    });
  });

  test('migrates every old protocol while keeping bookmark annotations', () {
    final original = testBookmark('legacy', name: 'Home', tags: ['relay'])
      ..extensions = {'vendor': 7};
    final decoded = decodeBookmarks(
      jsonEncode({
        'version': 1,
        'bookmarks': [
          {
            ...original.toJson(),
            'node': {
              'id': 'old relay',
              'url': 'wss://relay.example.com/ws',
              'port': 8787,
              'protocols': ['tcp', 'wss'],
              'publicKey': 'pin',
            },
          },
        ],
      }),
    );
    expect(decoded.bookmarks.map((b) => b.node.url.toString()), [
      'tcp://relay.example.com:8787/ws',
      'wss://relay.example.com:8787/ws',
    ]);
    expect(decoded.bookmarks.first.id, 'legacy');
    expect(decoded.bookmarks.map((b) => b.id).toSet(), hasLength(2));
    for (final bookmark in decoded.bookmarks) {
      expect(bookmark.name, 'Home');
      expect(bookmark.tags, ['relay']);
      expect(bookmark.extensions, {'vendor': 7});
      expect(bookmark.node.publicKey, 'pin');
      expect(bookmark.createdAt, original.createdAt);
    }
    expect(decodeBookmarks(encodeBookmarks(decoded)).bookmarks, hasLength(2));
  });

  test('an empty document holds nothing', () {
    final decoded = decodeBookmarks(
      encodeBookmarks(const BookmarkDocument(bookmarks: [])),
    );

    expect(decoded.bookmarks, isEmpty);
  });
}

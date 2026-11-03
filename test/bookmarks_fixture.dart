import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari/signals/bookmarks.dart' as saved;
import 'package:yukari/storage/bookmark_store.dart';
import 'package:yukari/utils/bookmark_codec.dart';

late BookmarkStore _store;

/// A bookmark store in a fresh temporary directory, deleted after the test.
BookmarkStore temporaryBookmarkStore() {
  final directory = Directory.systemTemp.createTempSync('yukari_bookmarks_');
  addTearDown(() => directory.delete(recursive: true));
  return BookmarkStore.inDirectory(directory.path);
}

/// A bookmark for `host`, using [id] as its node's id too.
Bookmark testBookmark(
  String id, {
  String host = 'relay.example.com',
  int port = 11010,
  List<NodeProtocol> protocols = const [NodeProtocol.tcp],
  String? name,
  String? description,
  String? category,
  List<String> tags = const [],
}) => Bookmark(
  id: id,
  node: Node(id: id, url: Uri.parse(host), port: port, protocols: protocols),
  name: name,
  description: description,
  category: category,
  tags: tags,
);

/// Seeds the bookmarks signal with [bookmarks] from a fresh store.
Future<void> seedBookmarks([List<Bookmark> bookmarks = const []]) async {
  _store = temporaryBookmarkStore();
  await _store.save(BookmarkDocument(bookmarks: bookmarks));
  await saved.init(_store);
  addTearDown(saved.dispose);
}

/// The persisted document, including its custom extensions.
///
/// Reads synchronously, as file futures never complete in fake-async zones.
BookmarkDocument persistedDocument() =>
    decodeBookmarks(_store.file.readAsStringSync());

/// The bookmarks as persisted in the store.
List<Bookmark> persistedBookmarks() => persistedDocument().bookmarks;

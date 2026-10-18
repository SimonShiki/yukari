import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/bookmark_codec.dart';
import 'package:yukari_core/storage/json_file.dart';

/// The user's bookmarks in `bookmarks.json` in the app data directory.
///
/// Unlike the network store, the background service never reads this file:
/// the app is its only writer and only reader.
final class BookmarkStore {
  BookmarkStore(this.file);

  /// The store kept in the data directory [dataDir].
  factory BookmarkStore.inDirectory(String dataDir) =>
      BookmarkStore(File(p.join(dataDir, 'bookmarks.json')));

  final File file;

  /// Saved bookmarks in display order; empty when nothing was saved yet.
  ///
  /// Custom extension data written by an import is kept alongside them, so
  /// an export writes back what the document arrived with.
  Future<BookmarkDocument> load() async {
    if (!await file.exists()) return const BookmarkDocument(bookmarks: []);
    return decodeBookmarks(await file.readAsString());
  }

  /// Replaces the saved bookmarks with [document], keeping their order.
  Future<void> save(BookmarkDocument document) =>
      replaceWithJson(file, document.toJson());
}

import 'package:signals/signals.dart';

import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';

import '../storage/bookmark_store.dart';
import '../utils/bookmark_codec.dart';
import '../utils/optimistic_store.dart';

/// Private backing signal for the user's bookmarks.
/// Use [bookmarks] for readonly access.
final Signal<List<Bookmark>> _bookmarks = signal(const <Bookmark>[]);

/// Private backing signal for document-wide custom extensions.
final Signal<Map<String, Object?>> _extensions = signal(const {});

/// The user's saved bookmarks, in display order.
///
/// [init] loads them once at startup. [addBookmark], [addBookmarks],
/// [updateBookmark] and [deleteBookmark] change the list; each writes to the
/// [BookmarkStore] optimistically and rolls back when the write fails.
ReadonlySignal<List<Bookmark>> get bookmarks => _bookmarks;

/// Custom extension data an imported document carried, written back on the
/// next export so a round trip does not drop another tool's fields.
ReadonlySignal<Map<String, Object?>> get bookmarkExtensions => _extensions;

BookmarkStore? _store;

/// Runs every bookmark mutation one at a time.
final _mutations = MutationQueue();

/// Loads the persisted bookmarks and extensions into their signals.
///
/// Call once at app startup, before any bookmark operation.
Future<void> init(BookmarkStore store) async {
  await dispose();
  _store = store;
  final document = await store.load();
  _bookmarks.value = List.unmodifiable(document.bookmarks);
  _extensions.value = Map.unmodifiable(document.extensions);
}

Future<void> _save(List<Bookmark> bookmarks) => _store!.save(
  BookmarkDocument(bookmarks: bookmarks, extensions: _extensions.peek()),
);

/// The saved bookmark for [node], if the user already saved that address.
Bookmark? bookmarkFor(Node node) =>
    _bookmarks.peek().where((saved) => sameNode(saved.node, node)).firstOrNull;

/// Saves [bookmark].
///
/// Throws [StateError] if a bookmark with the same id exists.
Future<void> addBookmark(Bookmark bookmark) => _mutations.enqueue(() async {
  final saved = _bookmarks.peek();
  if (saved.any((existing) => existing.id == bookmark.id)) {
    throw StateError('Bookmark already exists: ${bookmark.id}');
  }
  await persistOptimistically(
    _bookmarks,
    List<Bookmark>.unmodifiable([...saved, bookmark]),
    _save,
  );
});

/// Saves every bookmark in [incoming] whose id or address is not saved yet,
/// as one write, together with [extensions] it arrived with. Returns how many
/// bookmarks were added.
Future<int> addBookmarks(
  Iterable<Bookmark> incoming, {
  Map<String, Object?> extensions = const {},
}) => _mutations.enqueue(() async {
  final saved = _bookmarks.peek();
  final merged = [...saved];
  for (final bookmark in incoming) {
    final duplicate = merged.any(
      (existing) =>
          existing.id == bookmark.id || sameNode(existing.node, bookmark.node),
    );
    if (!duplicate) merged.add(bookmark);
  }

  final added = merged.length - saved.length;
  // Extensions an earlier import left win over the incoming ones.
  final previousExtensions = _extensions.peek();
  final mergedExtensions = {...extensions, ...previousExtensions};
  if (added == 0 && mergedExtensions.length == previousExtensions.length) {
    return 0;
  }

  _extensions.value = Map.unmodifiable(mergedExtensions);
  try {
    await persistOptimistically(
      _bookmarks,
      List<Bookmark>.unmodifiable(merged),
      _save,
    );
  } catch (error) {
    _extensions.value = previousExtensions;
    rethrow;
  }
  return added;
});

/// Replaces the bookmark with the same id with [bookmark].
///
/// Throws [StateError] if that bookmark does not exist.
Future<void> updateBookmark(Bookmark bookmark) => _mutations.enqueue(() async {
  final saved = _bookmarks.peek();
  if (!saved.any((existing) => existing.id == bookmark.id)) {
    throw StateError('Bookmark does not exist: ${bookmark.id}');
  }
  final updated = [
    for (final existing in saved)
      if (existing.id == bookmark.id) bookmark else existing,
  ];
  await persistOptimistically(
    _bookmarks,
    List<Bookmark>.unmodifiable(updated),
    _save,
  );
});

/// Removes the bookmark with [id].
///
/// Silently succeeds when no bookmark has that id.
Future<void> deleteBookmark(String id) => _mutations.enqueue(() async {
  final saved = _bookmarks.peek();
  if (!saved.any((existing) => existing.id == id)) return;
  final remaining = saved.where((existing) => existing.id != id).toList();
  await persistOptimistically(
    _bookmarks,
    List<Bookmark>.unmodifiable(remaining),
    _save,
  );
});

/// Completes once every queued mutation has been persisted.
Future<void> settled() => _mutations.settled();

/// Drops the store, once the queued mutations finish.
Future<void> dispose() async {
  await settled();
  _store = null;
}

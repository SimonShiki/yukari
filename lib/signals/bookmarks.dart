import 'package:signals/signals.dart';

import '../models/bookmark.dart';
import '../models/node.dart';
import '../storage/bookmark_store.dart';
import '../utils/bookmark_codec.dart';

/// Private backing signal for the user's bookmarks.
/// Use [bookmarks] for readonly access.
final Signal<List<Bookmark>> _bookmarks = signal(const <Bookmark>[]);

/// Private backing signal for document-wide custom extensions.
final Signal<Map<String, Object?>> _extensions = signal(const {});

/// The user's saved bookmarks, in display order.
///
/// **Initialization**: Call [init] once at app startup.
///
/// **Mutation**: Use [addBookmark], [addBookmarks], [updateBookmark] and
/// [deleteBookmark]; each persists to the [BookmarkStore] optimistically and
/// rolls back when the write fails.
ReadonlySignal<List<Bookmark>> get bookmarks => _bookmarks;

/// Custom extension data an imported document carried, written back on the
/// next export so a round trip does not drop another tool's fields.
ReadonlySignal<Map<String, Object?>> get bookmarkExtensions => _extensions;

BookmarkStore? _store;

/// Operation queue to ensure sequential execution of all mutations.
Future<void> _operations = Future.value();

/// Loads the persisted bookmarks into [bookmarks].
///
/// Must be called once at app startup before any bookmark operation.
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

Future<T> _enqueue<T>(Future<T> Function() operation) {
  final result = _operations.then((_) => operation());
  _operations = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  return result;
}

Future<void> _optimistic(
  List<Bookmark> Function() optimisticUpdate,
  Future<void> Function() persistOperation,
) async {
  final snapshot = _bookmarks.peek();
  _bookmarks.value = List.unmodifiable(optimisticUpdate());
  try {
    await persistOperation();
  } catch (e) {
    _bookmarks.value = List.unmodifiable(snapshot);
    rethrow;
  }
}

/// The saved bookmark for [node], if the user already saved that address.
Bookmark? bookmarkFor(Node node) =>
    _bookmarks.peek().where((saved) => sameNode(saved.node, node)).firstOrNull;

/// Saves [bookmark].
///
/// Throws [StateError] if a bookmark with the same id exists. The update is
/// optimistic with automatic rollback when the write fails.
Future<void> addBookmark(Bookmark bookmark) => _enqueue(() async {
  final saved = _bookmarks.peek();
  if (saved.any((existing) => existing.id == bookmark.id)) {
    throw StateError('Bookmark already exists: ${bookmark.id}');
  }
  await _optimistic(
    () => [...saved, bookmark],
    () => _save([...saved, bookmark]),
  );
});

/// Saves every bookmark in [incoming] whose id or address is not saved yet,
/// as one write, together with [extensions] it arrived with. Returns how many
/// bookmarks were added.
Future<int> addBookmarks(
  Iterable<Bookmark> incoming, {
  Map<String, Object?> extensions = const {},
}) => _enqueue(() async {
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
    await _optimistic(() => merged, () => _save(merged));
  } catch (error) {
    _extensions.value = previousExtensions;
    rethrow;
  }
  return added;
});

/// Replaces the bookmark with the same id with [bookmark].
///
/// Throws [StateError] if that bookmark does not exist.
Future<void> updateBookmark(Bookmark bookmark) => _enqueue(() async {
  final saved = _bookmarks.peek();
  if (!saved.any((existing) => existing.id == bookmark.id)) {
    throw StateError('Bookmark does not exist: ${bookmark.id}');
  }
  final updated = [
    for (final existing in saved)
      if (existing.id == bookmark.id) bookmark else existing,
  ];
  await _optimistic(() => updated, () => _save(updated));
});

/// Removes the bookmark with [id].
///
/// Silently succeeds when no bookmark has that id.
Future<void> deleteBookmark(String id) => _enqueue(() async {
  final saved = _bookmarks.peek();
  if (!saved.any((existing) => existing.id == id)) return;
  final remaining = saved.where((existing) => existing.id != id).toList();
  await _optimistic(() => remaining, () => _save(remaining));
});

/// Completes once every queued mutation has been persisted.
Future<void> settled() => _operations;

/// Clean up resources when the bookmarks signal is no longer needed.
Future<void> dispose() async {
  await _operations;
  _store = null;
}

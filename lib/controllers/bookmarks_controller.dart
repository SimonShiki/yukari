import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

import '../constants/builtin_bookmarks.dart';
import 'package:yukari_core/models/bookmark.dart';
import '../signals/bookmarks.dart' as saved;
import '../signals/locale.dart';
import '../utils/bookmark_search.dart';
import 'multi_selection.dart';

part 'bookmarks_filters.dart';

/// The category a bookmark is filtered, listed and displayed under, trimmed.
///
/// One definition is what keeps `' Home '` behaving as `Home` in the filter,
/// the section lists and the row's overline.
String? bookmarkCategoryLabel(Bookmark bookmark) =>
    trimmedOrNull(bookmark.category);

/// [value] trimmed, or null when it is null or blank.
String? trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Everything the bookmarks page binds to.
///
/// Holds the filter state as small signals, derives one signal per piece of UI
/// above it, and owns the mutations; the page only builds widgets and calls
/// these methods. The filter actions live in `bookmarks_filters.dart`.
class BookmarksController {
  BookmarksController({
    required this.showMessage,
    List<Bookmark>? builtins,
    this.pickImportFile,
    this.saveExportFile,
  }) : _builtins = builtins ?? builtinBookmarks;

  /// Reports a user-visible outcome; the page shows it in a snackbar.
  final void Function(String message) showMessage;

  final List<Bookmark> _builtins;

  /// The platform file picker and saver, overridden by the tests.
  final Future<String?> Function()? pickImportFile;
  final Future<bool> Function(String name, String content)? saveExportFile;

  /// The search field's text, so [clearFilters] clears the field and the query
  /// in one step whichever entry point asked for it.
  final TextEditingController searchController = TextEditingController();

  /// The current search text.
  final query = signal('');

  /// The single selected category, null for all categories.
  final category = signal<String?>(null);

  /// The selected tags, matched with AND semantics.
  final tags = signal<Set<String>>(const <String>{});

  /// The built-in shared nodes first, then the user's bookmarks.
  late final allBookmarks = computed(
    () => [..._builtins, ...saved.bookmarks.value],
  );

  /// The distinct trimmed categories to filter by, sorted.
  late final categoryOptions = computed(
    () =>
        _filterInventory(this, (bookmark) => [bookmarkCategoryLabel(bookmark)]),
  );

  /// The distinct trimmed tags to filter by, sorted.
  late final tagOptions = computed(
    () => _filterInventory(this, (bookmark) => bookmark.tags),
  );

  /// [allBookmarks] after the category, tag and search filters.
  late final visibleBookmarks = computed(
    () => [
      for (final bookmark in allBookmarks.value)
        if (_matchesFilters(this, bookmark)) bookmark,
    ],
  );

  /// The visible built-in shared nodes.
  late final sharedBookmarks = computed(
    () => [
      for (final bookmark in visibleBookmarks.value)
        if (isBuiltinBookmark(bookmark)) bookmark,
    ],
  );

  /// The visible bookmarks the user saved.
  late final myBookmarks = computed(
    () => [
      for (final bookmark in visibleBookmarks.value)
        if (!isBuiltinBookmark(bookmark)) bookmark,
    ],
  );

  /// Whether there is anything at all, before filtering.
  late final hasBookmarks = computed(() => allBookmarks.value.isNotEmpty);

  /// Whether the filters left anything to show.
  late final hasMatches = computed(() => visibleBookmarks.value.isNotEmpty);

  /// The filter badge's count: the chosen category plus the selected tags. The
  /// search query is not a filter and does not count.
  late final activeFilterCount = computed(
    () => (category.value == null ? 0 : 1) + tags.value.length,
  );

  /// Whether there is a user bookmark to export; built-ins do not count.
  late final canExport = computed(() => saved.bookmarks.value.isNotEmpty);

  /// The ids the list can select, in the order it shows them: the selection
  /// follows the filters, and built-ins are shareable like any saved node.
  late final selectableIds = computed(
    () => [for (final bookmark in visibleBookmarks.value) bookmark.id],
  );

  /// The gallery-style selection the list runs, entered from the app bar.
  late final selection = MultiSelection(selectable: selectableIds);

  /// Saves [bookmark], reporting a failure instead of throwing into the UI.
  Future<bool> add(Bookmark bookmark) =>
      _write(() => saved.addBookmark(bookmark), l10n.value.bookmarksSaveFailed);

  /// Replaces the saved bookmark with the same id.
  Future<bool> update(Bookmark bookmark) => _write(
    () => saved.updateBookmark(bookmark),
    l10n.value.bookmarksSaveFailed,
  );

  /// Removes [bookmark], reporting a failure instead of throwing into the UI.
  Future<bool> delete(Bookmark bookmark) => _write(
    () => saved.deleteBookmark(bookmark.id),
    l10n.value.bookmarksDeleteFailed,
  );

  /// Runs a store mutation, turning a failure into [failed] and a false result.
  Future<bool> _write(
    Future<void> Function() mutation,
    String Function(String error) failed,
  ) async {
    try {
      await mutation();
      return true;
    } catch (error) {
      showMessage(failed('$error'));
      return false;
    }
  }

  /// Frees the search field and every signal this controller created.
  void dispose() {
    searchController.dispose();
    selection.dispose();
    for (final created in <ReadonlySignal<Object?>>[
      query,
      category,
      tags,
      allBookmarks,
      categoryOptions,
      tagOptions,
      visibleBookmarks,
      sharedBookmarks,
      myBookmarks,
      hasBookmarks,
      hasMatches,
      activeFilterCount,
      canExport,
      selectableIds,
    ]) {
      created.dispose();
    }
  }
}

part of 'bookmarks_controller.dart';

/// The page's filter and query actions, on top of the state
/// [BookmarksController] holds.
extension BookmarksFilters on BookmarksController {
  /// Replaces the search text, as the field's own `onChanged` does.
  void setQuery(String value) => query.value = value;

  /// Clears the search and the field's text.
  void clearQuery() {
    query.value = '';
    searchController.clear();
  }

  /// Clears the search, category and tags.
  ///
  /// The field's clear icon and the drawer's clear action both end up here, so
  /// neither can leave the field showing text the list no longer filters by.
  void clearFilters() {
    clearQuery();
    category.value = null;
    tags.value = const <String>{};
  }

  /// Selects [value] as the only category, or clears it when already selected.
  void toggleCategory(String value) =>
      category.value = category.value == value ? null : value;

  /// Adds [value] to the selected tags, or removes it when already selected.
  void toggleTag(String value) => tags.value = {
    for (final tag in tags.value)
      if (tag != value) tag,
    if (!tags.value.contains(value)) value,
  };
}

/// Whether [bookmark] passes [controller]'s category, tag and search filters.
bool _matchesFilters(BookmarksController controller, Bookmark bookmark) {
  final selected = controller.category.value;
  if (selected != null && bookmarkCategoryLabel(bookmark) != selected) {
    return false;
  }
  if (controller.tags.value.isNotEmpty) {
    final own = {for (final tag in bookmark.tags) trimmedOrNull(tag)}
      ..remove(null);
    if (!own.containsAll(controller.tags.value)) return false;
  }
  return bookmarkMatches(bookmark, controller.query.value);
}

/// The distinct, trimmed, sorted values [values] yields over every bookmark
/// [controller] knows, built-ins included.
List<String> _filterInventory(
  BookmarksController controller,
  Iterable<String?> Function(Bookmark) values,
) {
  final found = <String>{
    for (final bookmark in controller.allBookmarks.value)
      ...values(bookmark).map(trimmedOrNull).whereType<String>(),
  }.toList();
  return found..sort();
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals.dart';

import '../constants/builtin_bookmarks.dart';
import '../models/bookmark.dart';
import '../models/node.dart';
import '../signals/bookmarks.dart' as saved;
import '../signals/locale.dart';
import '../signals/networks.dart' as saved_networks;
import '../utils/bookmark_codec.dart';
import '../utils/bookmark_search.dart';

part 'bookmarks_actions.dart';

/// The state and mutations of the bookmarks page: what the search field and
/// the filter chips narrow down, and the writes the page performs.
class BookmarksController {
  BookmarksController({required this.showMessage, List<Bookmark>? builtins})
    : builtins = builtins ?? builtinBookmarks;

  /// Reports a message the user should see, such as a failed import.
  final void Function(String message) showMessage;

  /// Shared nodes offered out of the box, listed before the saved ones.
  final List<Bookmark> builtins;

  /// Text typed into the search field; empty shows everything.
  final query = signal('');

  /// The selected category, or null for every category.
  final category = signal<String?>(null);

  /// Tags every shown bookmark must carry; empty shows every tag.
  final tags = signal<Set<String>>(const {});

  /// The built-in shared nodes followed by the user's saved bookmarks.
  late final all = computed(() => [...builtins, ...saved.bookmarks.value]);

  /// [all], narrowed down by [query], [category] and [tags].
  late final visible = computed(
    () => [
      for (final bookmark in all.value)
        if (_matches(bookmark)) bookmark,
    ],
  );

  /// Categories in use by any bookmark, sorted, for the filter chips.
  late final categories = computed(() {
    final categories = {
      for (final bookmark in all.value)
        if (bookmark.category case final category?
            when category.trim().isNotEmpty)
          category,
    };
    return categories.toList()..sort();
  });

  /// Tags in use by any bookmark, sorted, for the filter chips.
  late final availableTags = computed(() {
    final tags = {for (final bookmark in all.value) ...bookmark.tags};
    return tags.toList()..sort();
  });

  bool _matches(Bookmark bookmark) {
    if (category.value case final category?
        when bookmark.category != category) {
      return false;
    }
    if (!tags.value.every(bookmark.tags.contains)) return false;
    return bookmarkMatches(bookmark, query.value);
  }

  /// Whether a filter beyond the search text is narrowing the list down.
  bool get filtered => activeFilterCount > 0 || query.value.isNotEmpty;

  /// How many sidebar filters — a category or tags — are narrowing the list.
  int get activeFilterCount =>
      (category.value == null ? 0 : 1) + tags.value.length;

  /// Shows every bookmark again.
  void clearFilters() {
    query.value = '';
    category.value = null;
    tags.value = const {};
  }

  /// Adds [tag] to the required tags, or removes it when already selected.
  void toggleTag(String tag) {
    final selected = {...tags.value};
    if (!selected.remove(tag)) selected.add(tag);
    tags.value = selected;
  }

  /// Saves [bookmark], reporting a failure instead of throwing.
  void add(Bookmark bookmark) {
    try {
      saved.addBookmark(bookmark);
    } catch (error) {
      showMessage(l10n.value.bookmarksSaveFailed('$error'));
    }
  }

  /// Writes the changes made to an existing [bookmark].
  void update(Bookmark bookmark) {
    try {
      saved.updateBookmark(bookmark);
    } catch (error) {
      showMessage(l10n.value.bookmarksSaveFailed('$error'));
    }
  }

  /// Removes [bookmark] after the page confirmed it.
  void delete(Bookmark bookmark) {
    try {
      saved.deleteBookmark(bookmark.id);
    } catch (error) {
      showMessage(l10n.value.bookmarksDeleteFailed('$error'));
    }
  }

  void dispose() {
    query.dispose();
    category.dispose();
    tags.dispose();
    all.dispose();
    visible.dispose();
    categories.dispose();
    availableTags.dispose();
  }
}

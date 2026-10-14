import '../models/bookmark.dart';

/// Whether [bookmark] matches [query], compared case-insensitively against
/// its name, address, category, description and tags.
///
/// An empty [query] matches everything.
bool bookmarkMatches(Bookmark bookmark, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return [
    bookmark.displayName,
    bookmark.address,
    bookmark.category ?? '',
    bookmark.description ?? '',
    ...bookmark.tags,
  ].any((value) => value.toLowerCase().contains(needle));
}

import 'dart:convert';

import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';

/// The format version [encodeBookmarks] writes; a document from a newer
/// version is refused rather than guessed at.
const int bookmarkDocumentVersion = 2;

/// A parsed bookmarks document: the bookmarks plus whatever custom extension
/// data the document carried, which [encodeBookmarks] writes back untouched.
final class BookmarkDocument {
  const BookmarkDocument({
    required this.bookmarks,
    this.exportedAt,
    this.extensions = const {},
  });

  final List<Bookmark> bookmarks;
  final DateTime? exportedAt;
  final Map<String, Object?> extensions;

  /// The document as JSON, ready to write to a store or an export file.
  Map<String, Object?> toJson() => {
    'version': bookmarkDocumentVersion,
    if (exportedAt case final exportedAt?)
      'exportedAt': exportedAt.toUtc().toIso8601String(),
    'bookmarks': [for (final bookmark in bookmarks) bookmark.toJson()],
    if (extensions.isNotEmpty) 'extensions': extensions,
  };
}

/// Encodes [document] as pretty JSON, keeping its custom extensions.
String encodeBookmarks(BookmarkDocument document) =>
    const JsonEncoder.withIndent('  ').convert(document.toJson());

/// Parses a bookmarks document, accepting either the object [encodeBookmarks]
/// writes or a bare array of bookmarks.
///
/// Imported files are untrusted, so every entry is checked and a malformed
/// file throws a [FormatException] instead of loading half of it.
BookmarkDocument decodeBookmarks(String content) {
  final Object? root;
  try {
    root = jsonDecode(content);
  } on FormatException catch (error) {
    throw FormatException('Not valid JSON: ${error.message}');
  }

  final Map<String, Object?> metadata;
  final List<Object?> entries;
  switch (root) {
    case List<Object?> list:
      metadata = const {};
      entries = list;
    case Map<String, Object?> document:
      metadata = document;
      if (document['version'] case final int version
          when version > bookmarkDocumentVersion) {
        throw FormatException(
          'Bookmarks format version $version is newer than version '
          '$bookmarkDocumentVersion',
        );
      }
      if (document['bookmarks'] case final List<Object?> list) {
        entries = list;
      } else {
        throw const FormatException('The document has no "bookmarks" list');
      }
    default:
      throw const FormatException('Expected a bookmarks object or list');
  }

  final bookmarks = <Bookmark>[
    for (final (index, entry) in entries.indexed) ..._decode(entry, index),
  ];

  return BookmarkDocument(
    bookmarks: bookmarks,
    exportedAt: switch (metadata['exportedAt']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
    extensions: _extensions(metadata),
  );
}

const _knownKeys = {'version', 'exportedAt', 'bookmarks', 'extensions'};

/// Top-level keys the format does not own, merged with an explicit
/// `extensions` object so both styles survive a round trip.
Map<String, Object?> _extensions(Map<String, Object?> document) => {
  for (final MapEntry(:key, :value) in document.entries)
    if (!_knownKeys.contains(key)) key: value,
  if (document['extensions'] case final Map<String, Object?> extra) ...extra,
};

List<Bookmark> _decode(Object? entry, int index) {
  final position = index + 1;
  if (entry is! Map<String, Object?>) {
    throw FormatException('Bookmark $position is not an object');
  }

  try {
    final nodeJson = entry['node'] as Map<String, dynamic>;
    if (!nodeJson.containsKey('protocols')) {
      return [_validatedBookmark(entry, position)];
    }
    final nodes = nodesFromJson(nodeJson);
    return [
      for (final (index, node) in nodes.indexed)
        _validatedBookmark({
          ...entry,
          if (index > 0) 'id': '${entry['id']}:${node.url}',
          'node': node.toJson(),
        }, position),
    ];
  } catch (error) {
    throw FormatException('Bookmark $position is malformed: $error');
  }
}

Bookmark _validatedBookmark(Map<String, dynamic> entry, int position) {
  final bookmark = Bookmark.fromJson(entry);
  if (bookmark.id.trim().isEmpty) {
    throw FormatException('Bookmark $position has no id');
  }
  if (!isValidNodeUrl((entry['node'] as Map)['url'] as String)) {
    throw FormatException('Bookmark $position has an invalid connection URL');
  }
  return bookmark;
}

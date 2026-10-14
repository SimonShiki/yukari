import 'package:json_annotation/json_annotation.dart';

import 'node.dart';

part 'bookmark.g.dart';

/// A saved peer [Node] with the metadata needed to find and reuse it.
///
/// Bookmarks are the values the bookmarks page and the network editor's
/// initial-peers section share. Only the user's own bookmarks are persisted;
/// the built-in shared nodes live in `constants/builtin_bookmarks.dart`.
@JsonSerializable(explicitToJson: true)
final class Bookmark {
  Bookmark({
    required this.id,
    required this.node,
    this.name,
    this.description,
    this.category,
    this.tags = const [],
    this.extensions = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Bookmark.fromJson(Map<String, dynamic> json) =>
      _$BookmarkFromJson(json);

  Map<String, dynamic> toJson() => _$BookmarkToJson(this);

  String id;
  Node node;
  String? name;
  String? description;

  /// Free-form group, empty for uncategorized bookmarks.
  String? category;
  List<String> tags;

  /// Custom extension fields, kept exactly as they arrived so an
  /// export/import round trip does not drop another tool's data.
  Map<String, Object?> extensions;
  DateTime createdAt;
  DateTime updatedAt;

  /// The name shown in lists, falling back to the node's host.
  String get displayName {
    final name = this.name?.trim();
    return name == null || name.isEmpty ? nodeHost(node.url) : name;
  }

  /// `host:port`, the address a list shows under the name.
  String get address => '${nodeHost(node.url)}:${node.port}';
}

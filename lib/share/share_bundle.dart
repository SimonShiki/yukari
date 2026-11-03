import 'dart:convert';

import 'share_document.dart';

/// The most documents one share may carry.
const int shareMaxBundleItems = 24;

/// The wire kind a bundle carries.
///
/// [ShareKind] stays two-valued: a bundle is a shape the transport carries, not
/// something a network or a node can be, so nothing that switches on a kind has
/// to know about it.
const String shareBundleKind = 'bundle';

/// [items] as the payload a share channel carries.
///
/// One item encodes exactly as [ShareDocument.encode] does, so a single-target
/// link or QR code carries that document's own JSON. More
/// than one becomes a bundle the receiver splits back into documents; an app
/// older than bundles refuses one with `Unknown share kind: bundle` instead of
/// half-accepting it.
String encodeShareItems(List<ShareDocument> items) {
  if (items.isEmpty) {
    throw ArgumentError.value(
      items,
      'items',
      'A share carries at least one item',
    );
  }
  if (items.length > shareMaxBundleItems) {
    throw ArgumentError.value(
      items,
      'items',
      'A share carries at most $shareMaxBundleItems items',
    );
  }
  final kind = items.first.kind;
  if (items.any((item) => item.kind != kind)) {
    throw ArgumentError.value(items, 'items', 'A share carries one kind');
  }
  if (items.length == 1) return items.single.encode();
  return jsonEncode({
    'v': shareDocumentVersion,
    'kind': shareBundleKind,
    'items': [for (final item in items) item.toJson()],
  });
}

/// The documents [content] carries, rejecting anything malformed.
///
/// The same byte cap and field checks as [ShareDocument.decode]; a bundle is
/// all-or-nothing, so one bad item throws a [FormatException] and never yields
/// a partial bundle.
List<ShareDocument> decodeShareItems(String content) {
  final root = ShareDocument.parseRoot(content);
  // Anything that is not a bundle is a document, and its own validator decides.
  if (root['kind'] != shareBundleKind) return [ShareDocument.decodeRoot(root)];

  final version = root['v'];
  if (version != shareDocumentVersion) {
    throw FormatException('Unsupported share format version: $version');
  }
  final items = root['items'];
  if (items is! List<Object?> ||
      items.isEmpty ||
      items.length > shareMaxBundleItems) {
    throw FormatException('A share bundle has an invalid item count');
  }
  final documents = <ShareDocument>[];
  for (final (index, entry) in items.indexed) {
    if (entry is! Map<String, Object?>) {
      throw FormatException('Bundle item ${index + 1} is not an object');
    }
    documents.add(ShareDocument.decodeRoot(entry));
  }
  if (documents.any((document) => document.kind != documents.first.kind)) {
    throw FormatException('A share bundle mixes share kinds');
  }
  return documents;
}

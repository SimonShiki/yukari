import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';
import '../signals/bookmarks.dart' as saved;
import '../signals/locale.dart';
import '../share/share_document.dart';
import '../share/share_selection.dart';
import '../signals/networks.dart' as networks;
import '../utils/bookmark_codec.dart';
import '../utils/file_save.dart';
import 'bookmarks_controller.dart';

/// The file an export writes.
const String bookmarkExportFileName = 'yukari-bookmarks.json';

/// The raw values the bookmark editor collected, before they are trimmed into
/// a [Bookmark].
typedef BookmarkDraft = ({
  Node node,
  String name,
  String description,
  String category,
  String tags,
});

/// Reads the content of a bookmarks file; null when the user cancelled, and
/// throws when the picked file cannot be read.
typedef BookmarkFilePicker = Future<String?> Function();

/// Writes [content] under [name] where the user chose to; false when the user
/// cancelled, and throws when the write failed.
typedef BookmarkFileSaver = Future<bool> Function(String name, String content);

/// One row of the add-to-network picker.
typedef BookmarkNetworkOption = ({String id, String name, bool contains});

/// The user actions that are not filter state: composing, saving, deleting,
/// sharing, copying and the file round trip.
extension BookmarksActions on BookmarksController {
  /// The bookmark [draft] describes, updating [existing] in place of a new one.
  ///
  /// Blank optional fields become null, tags are deduplicated, and an edit
  /// keeps its id, creation time and extensions while stamping a new time.
  Bookmark compose({Bookmark? existing, required BookmarkDraft draft}) {
    final now = DateTime.now().toUtc();
    return Bookmark(
      id: existing?.id ?? const Uuid().v4(),
      node: draft.node,
      name: trimmedOrNull(draft.name),
      description: trimmedOrNull(draft.description),
      category: trimmedOrNull(draft.category),
      tags: _splitTags(draft.tags),
      extensions: existing?.extensions ?? const {},
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Composes [draft] and saves it as a new bookmark or an update.
  Future<bool> save({Bookmark? existing, required BookmarkDraft draft}) {
    final bookmark = compose(existing: existing, draft: draft);
    return existing == null ? add(bookmark) : update(bookmark);
  }

  /// The saved networks with whether each already holds [bookmark]'s node, for
  /// the add-to-network picker.
  List<BookmarkNetworkOption> networkOptions(Bookmark bookmark) => [
    for (final MapEntry(key: id, value: network)
        in networks.networks.value.entries)
      (
        id: id,
        name: network.networkName,
        contains: network.nodes.any((node) => sameNode(node, bookmark.node)),
      ),
  ];

  /// Appends a copy of [bookmark]'s node to the saved network [networkId].
  ///
  /// An unknown network does nothing, and a node the network already has only
  /// reports it.
  Future<void> addToNetwork(Bookmark bookmark, String networkId) async {
    final network = networks.networks.value[networkId];
    if (network == null) return;
    if (network.nodes.any((node) => sameNode(node, bookmark.node))) {
      showMessage(l10n.value.bookmarksAlreadyInNetwork(network.networkName));
      return;
    }
    try {
      await networks.updateNetwork(
        networkId,
        network.copy()..nodes = [...network.nodes, bookmark.node.copy()],
      );
      showMessage(l10n.value.bookmarksAddedToNetwork(network.networkName));
    } catch (error) {
      showMessage(l10n.value.bookmarksAddToNetworkFailed('$error'));
    }
  }

  /// Copies [bookmark]'s address to the clipboard.
  Future<void> copyAddress(Bookmark bookmark) async {
    try {
      await Clipboard.setData(ClipboardData(text: bookmark.address));
      showMessage(l10n.value.bookmarksCopied(bookmark.address));
    } on Exception {
      // The clipboard is the platform's; nothing was changed to undo.
    }
  }

  // The one share channel that is described but not implemented yet.
  void shareOverNetwork() => showMessage(l10n.value.bookmarksShareUnavailable);

  /// The route that shares every selected node as one bundle, or null after
  /// reporting what cannot be shared.
  String? selectionShareRoute() => shareSelection(
    kind: ShareKind.node,
    selection: selection,
    showMessage: showMessage,
  );

  /// Deletes every selected bookmark behind one confirmation the page asked
  /// for, reporting a store failure once and leaving selection either way.
  ///
  /// The built-in shared nodes are never deleted here: they are not the
  /// store's, so a selection holding only those deletes nothing.
  Future<void> deleteSelection() async {
    final targets = selectedBookmarks.value;
    if (targets.isEmpty) return;
    try {
      for (final bookmark in targets) {
        await saved.deleteBookmark(bookmark.id);
      }
    } catch (error) {
      showMessage(l10n.value.bookmarksDeleteSelectedFailed('$error'));
    }
    // The page may be gone by now, and its selection with it.
    if (!isDisposed) selection.exit();
  }

  /// Imports the bookmarks of a picked JSON file.
  ///
  /// A dismissed picker does nothing; every other outcome reports itself.
  Future<void> importFromFile() async {
    final String? content;
    try {
      content = await (pickImportFile ?? _pickJsonFile)();
    } catch (_) {
      showMessage(l10n.value.bookmarksFileUnavailable);
      return;
    }
    if (content == null) return;

    final BookmarkDocument document;
    try {
      document = decodeBookmarks(content);
    } on FormatException catch (error) {
      showMessage(l10n.value.bookmarksImportInvalid(error.message));
      return;
    } catch (error) {
      showMessage(l10n.value.bookmarksImportFailed('$error'));
      return;
    }

    try {
      final added = await saved.addBookmarks(
        document.bookmarks,
        extensions: document.extensions,
      );
      showMessage(
        added == 0
            ? l10n.value.bookmarksImportNothingNew
            : l10n.value.bookmarksImported(added),
      );
    } catch (error) {
      showMessage(l10n.value.bookmarksImportFailed('$error'));
    }
  }

  /// Writes every saved bookmark to a JSON file, whatever the filters show.
  ///
  /// A dismissed save dialog does nothing; a failed write is reported.
  Future<void> exportToFile() async {
    try {
      final document = BookmarkDocument(
        bookmarks: saved.bookmarks.value,
        exportedAt: DateTime.now().toUtc(),
        extensions: saved.bookmarkExtensions.value,
      );
      final written = await (saveExportFile ?? _saveJsonFile)(
        bookmarkExportFileName,
        encodeBookmarks(document),
      );
      if (written) showMessage(l10n.value.bookmarksExported);
    } catch (error) {
      showMessage(l10n.value.bookmarksExportFailed('$error'));
    }
  }
}

/// Comma-split, trimmed, blank-dropped and deduplicated tags.
List<String> _splitTags(String value) =>
    {for (final raw in value.split(',')) ?trimmedOrNull(raw)}.toList();

/// Picks a JSON file and reads it; null when the user cancelled.
Future<String?> _pickJsonFile() async {
  final picked = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (picked == null) return null;
  return utf8.decode(await picked.readAsBytes());
}

/// Writes [content] under [name] where the user chose to; false when cancelled.
Future<bool> _saveJsonFile(String name, String content) =>
    saveTextFile(name, content, mimeType: 'application/json');

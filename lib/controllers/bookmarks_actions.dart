part of 'bookmarks_controller.dart';

/// File transfer, sharing and network writes of the bookmarks page, kept
/// apart from the [BookmarksController] state.
extension BookmarkActions on BookmarksController {
  /// Reads a bookmarks JSON file the user picked and saves what is new.
  Future<void> importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: l10n.value.bookmarksImportFile,
      );
      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) {
        showMessage(l10n.value.bookmarksFileUnavailable);
        return;
      }

      // Imported files are untrusted: every entry is validated by the codec.
      final document = decodeBookmarks(await File(file.path!).readAsString());
      final added = await saved.addBookmarks(
        document.bookmarks,
        extensions: document.extensions,
      );
      showMessage(
        added == 0
            ? l10n.value.bookmarksImportNothingNew
            : l10n.value.bookmarksImported(added),
      );
    } on FormatException catch (error) {
      showMessage(l10n.value.bookmarksImportInvalid(error.message));
    } catch (error) {
      showMessage(l10n.value.bookmarksImportFailed('$error'));
    }
  }

  /// Writes [bookmarks] — every bookmark by default — to a JSON file the
  /// user picks, in the same format [importFromFile] reads.
  Future<void> exportToFile([Iterable<Bookmark>? bookmarks]) async {
    final exported = [...(bookmarks ?? saved.bookmarks.value)];
    try {
      final content = encodeBookmarks(
        BookmarkDocument(
          bookmarks: exported,
          exportedAt: DateTime.now().toUtc(),
          extensions: saved.bookmarkExtensions.value,
        ),
      );
      final uri = await FilePicker.saveFile(
        fileName: 'yukari-bookmarks.json',
        bytes: utf8.encode(content),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: l10n.value.bookmarksExportFile,
      );
      if (uri != null) showMessage(l10n.value.bookmarksExported);
    } catch (error) {
      showMessage(l10n.value.bookmarksExportFailed('$error'));
    }
  }

  /// Sends [bookmark] to another Yukari over a connected network.
  ///
  /// A stub: the FFI data plane will carry the document later.
  void shareOverNetwork(Bookmark bookmark) =>
      showMessage(l10n.value.bookmarksShareUnavailable);

  /// Shows [bookmark] as a QR code for another device to scan.
  ///
  /// A stub until QR encoding lands.
  void showQrCode(Bookmark bookmark) =>
      showMessage(l10n.value.bookmarksQrUnavailable);

  /// Reads a bookmark another device shows as a QR code.
  ///
  /// A stub until QR scanning lands.
  void scanQrCode() => showMessage(l10n.value.bookmarksScanUnavailable);

  /// Copies the bookmark's peer address as `host:port`.
  Future<void> copyAddress(Bookmark bookmark) async {
    await Clipboard.setData(ClipboardData(text: bookmark.address));
    showMessage(l10n.value.bookmarksCopied(bookmark.address));
  }

  /// Adds [bookmark]'s node to the network saved under [networkId].
  Future<void> addToNetwork(Bookmark bookmark, String networkId) async {
    final network = saved_networks.networks.value[networkId];
    if (network == null) return;
    if (network.nodes.any((node) => sameNode(node, bookmark.node))) {
      showMessage(l10n.value.bookmarksAlreadyInNetwork(network.networkName));
      return;
    }

    // The saved network stays untouched until the store accepted the change.
    final updated = network.copy()
      ..nodes = [...network.nodes, bookmark.node.copy()];
    try {
      await saved_networks.updateNetwork(networkId, updated);
      showMessage(l10n.value.bookmarksAddedToNetwork(network.networkName));
    } catch (error) {
      showMessage(l10n.value.bookmarksAddToNetworkFailed('$error'));
    }
  }
}

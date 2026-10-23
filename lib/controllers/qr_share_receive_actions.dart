part of 'qr_share_receive_controller.dart';

/// The receive page's two asynchronous actions: scanning a picked image for
/// payloads, and adding the share it produced to the app.
extension QrShareReceiveActions on QrShareReceiveController {
  /// Scans a picked image or GIF, feeding every payload it finds into the
  /// session.
  ///
  /// The scan is pure Dart and runs in a worker isolate; an image with no QR
  /// code is reported as [l10n.shareReceiveImageEmpty].
  Future<void> scanImage(Uint8List bytes) async {
    if (_disposed || saving.value || shares.value.isNotEmpty) return;
    if (imageProgress.value != null) return;

    error.value = null;
    imageProgress.value = (done: 0, total: 0);
    final scan = ++_imageScan;
    var found = 0;
    try {
      await _imageScanner(
        bytes,
        onProgress: (done, total) {
          // A reset or a dispose ends this scan's right to touch the signals.
          if (_disposed || scan != _imageScan) return;
          imageProgress.value = (done: done, total: total);
        },
        onPayload: (payload) {
          if (_disposed || scan != _imageScan) return;
          found++;
          addPayload(payload);
        },
        isCancelled: () =>
            _disposed || scan != _imageScan || _session.isComplete,
      );
    } on Object catch (exception) {
      if (!_disposed && scan == _imageScan) {
        error.value = l10n.value.shareReceiveImageFailed('$exception');
      }
    } finally {
      if (!_disposed && scan == _imageScan) imageProgress.value = null;
    }
    if (!_disposed && scan == _imageScan && found == 0 && error.value == null) {
      error.value = l10n.value.shareReceiveImageEmpty;
    }
  }

  /// Adds [shares] to the app: a network, or the node it describes.
  ///
  /// Returns false when there is nothing to add, when a save is already running
  /// or when the shares were saved before, so a double tap cannot add them
  /// twice.
  Future<bool> save() async {
    if (_disposed) return false;
    final documents = shares.value;
    if (documents.isEmpty || saving.value || saved.value) return false;

    saving.value = true;
    try {
      // One share keeps the message that names it, which the batch summary has
      // no room for; a bundle reports what the batch did.
      final message = documents.length == 1
          ? await _saveOne(documents.single)
          : await _addAll(documents);
      if (_disposed) return true;
      saved.value = true;
      showMessage?.call(message);
      return true;
    } on Object catch (exception) {
      if (!_disposed) {
        showMessage?.call(l10n.value.shareReceiveAddFailed('$exception'));
      }
      return false;
    } finally {
      if (!_disposed) saving.value = false;
    }
  }

  /// Saves the one [document] and says what it became.
  Future<String> _saveOne(ShareDocument document) async =>
      switch (document.kind) {
        ShareKind.network => l10n.value.shareReceiveNetworkAdded(
          await _importer.addNetwork(document),
        ),
        ShareKind.node => switch (await _importer.addNode(document)) {
          final address? => l10n.value.shareReceiveNodeSaved(address),
          null => l10n.value.shareReceiveNodeExists,
        },
      };

  /// Saves every document in [documents] and says what the batch did.
  Future<String> _addAll(List<ShareDocument> documents) async {
    final summary = await addSharedDocuments(documents, importer: _importer);
    return summary.added == documents.length
        ? l10n.value.shareReceiveAddedAll(summary.added)
        : l10n.value.shareReceiveAddSummary(
            summary.added,
            summary.duplicates,
            summary.failed,
          );
  }
}

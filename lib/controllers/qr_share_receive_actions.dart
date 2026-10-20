part of 'qr_share_receive_controller.dart';

/// The receive page's two asynchronous actions: scanning a picked image for
/// payloads, and adding the share it produced to the app.
extension QrShareReceiveActions on QrShareReceiveController {
  /// Scans a picked image or GIF, feeding every payload it finds into the
  /// session.
  ///
  /// The scan is pure Dart and, where the platform has isolates, runs in a
  /// worker isolate; an image with no QR code is reported as
  /// [l10n.shareReceiveImageEmpty].
  Future<void> scanImage(Uint8List bytes) async {
    if (_disposed || saving.value || share.value != null) return;
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

  /// Adds [share] to the app: a network, or the node it describes.
  ///
  /// Returns false when there is nothing to add, when a save is already running
  /// or when the share was saved before, so a double tap cannot add it twice.
  Future<bool> save() async {
    if (_disposed) return false;
    final document = share.value;
    if (document == null || saving.value || saved.value) return false;

    saving.value = true;
    try {
      final message = switch (document.kind) {
        ShareKind.network => l10n.value.shareReceiveNetworkAdded(
          await _importer.addNetwork(document),
        ),
        ShareKind.node => switch (await _importer.addNode(document)) {
          final address? => l10n.value.shareReceiveNodeSaved(address),
          null => l10n.value.shareReceiveNodeExists,
        },
      };
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
}

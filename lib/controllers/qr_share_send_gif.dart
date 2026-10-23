part of 'qr_share_send_controller.dart';

/// The GIF export half of the sender: a stream a receiver without a camera can
/// scan from a looping image.
extension QrShareSendGif on QrShareSendController {
  /// Frames a GIF export writes: the blocks plus a third again, at least four,
  /// so a receiver that misses frames still recovers the payload.
  int get gifFrameCount =>
      blockCount.value + max(4, (blockCount.value * 0.3).ceil());

  /// Encodes the stream as an animated GIF for a receiver without a camera.
  ///
  /// The live stream pauses for the whole export, since both encode QR codes
  /// on the same isolate and only one of them can be on screen, and it stays
  /// paused afterwards. Encoding is abortable through [cancelExport] and on
  /// dispose.
  Future<Uint8List?> exportGif({
    void Function(int done, int total)? onProgress,
  }) async {
    final total = gifFrameCount;
    if (_disposed || total == 0) return null;
    pause();
    _exportCancelled = false;
    exporting.value = true;
    try {
      // A fountain draw can miss a block by chance, and qrs refuses to write a
      // GIF that cannot recover; a fresh draw almost always succeeds, so the
      // export retries a couple of times before reporting a failure. The
      // export draws its own randomness: reusing the live session's generator
      // would continue its sequence on every retry instead of starting over.
      for (var attempt = 0; ; attempt++) {
        exported.value = 0;
        try {
          return await _encodeGif(total, onProgress);
        } on StateError {
          if (_disposed || _exportCancelled || attempt >= 2) rethrow;
        }
      }
    } finally {
      if (!_disposed) exporting.value = false;
      _exportCancelled = false;
    }
  }

  /// Asks the running GIF export to stop; a cancelled export returns null.
  void cancelExport() => _exportCancelled = true;

  Future<Uint8List?> _encodeGif(
    int frames,
    void Function(int done, int total)? onProgress,
  ) => encodeGif(
    GifExportOptions(
      data: _session.data,
      frames: frames,
      sliceSize: _sliceSize,
      size: 512,
      fps: 10,
      compress: true,
      prefix: '',
      isAborted: () => _disposed || _exportCancelled,
      onProgress: (done) {
        if (_disposed) return;
        exported.value = done;
        onProgress?.call(done, frames);
      },
    ),
  );
}

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'image_qr_decode.dart';

export 'image_qr_decode.dart' show ImageScanReport, decodeImageForQrPayloads;

/// Decodes every QR code in [bytes] **without blocking the UI thread**.
///
/// The image may be a still bitmap or an animated GIF, including the GIF the
/// share page exports. This is the scanning path for platforms that
/// `mobile_scanner` has no camera plugin for, such as Linux and Windows, and
/// the fallback everywhere else when the user picks an image instead of using
/// the camera.
///
/// The work is CPU bound, so on every platform that has isolates it runs in a
/// short-lived worker isolate and the UI isolate only receives progress,
/// payloads and the final report. The web has no isolates: there the same
/// decoder runs in-process but yields to the event loop between frames.
///
/// [onProgress] reports `(done, total)` frames, [onPayload] fires as soon as a
/// frame decodes so the receiver can be fed live, and [isCancelled] is polled
/// while the worker runs; cancelling keeps the payloads found so far.
Future<ImageScanReport> scanImageForQrPayloads(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
  void Function(String payload)? onPayload,
  bool Function()? isCancelled,
}) {
  if (kIsWeb) {
    return decodeImageForQrPayloads(
      bytes,
      onProgress: onProgress,
      onPayload: onPayload,
      isCancelled: isCancelled,
    );
  }
  return _scanInWorker(
    bytes,
    onProgress: onProgress,
    onPayload: onPayload,
    isCancelled: isCancelled,
  );
}

/// Scans a picked image for QR payloads; [scanImageForQrPayloads]'s signature.
typedef ImageScanner = Future<ImageScanReport> Function(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
  void Function(String payload)? onPayload,
  bool Function()? isCancelled,
});

/// A progress report from the worker isolate.
class _WorkerProgress {
  const _WorkerProgress(this.done, this.total);

  final int done;
  final int total;
}

/// A payload decoded by the worker isolate.
class _WorkerPayload {
  const _WorkerPayload(this.payload);

  final String payload;
}

/// The final message of the worker isolate.
class _WorkerFinished {
  const _WorkerFinished({required this.frameCount, this.failure});

  final int frameCount;
  final String? failure;
}

/// Entry point of the worker isolate.
///
/// The spawn message carries both the port to report on and the image bytes, so
/// there is no handshake before decoding starts.
Future<void> _decodeWorker(List<Object?> arguments) async {
  final toUi = arguments[0] as SendPort;
  final bytes = arguments[1] as Uint8List;

  try {
    final report = await decodeImageForQrPayloads(
      bytes,
      onProgress: (done, total) => toUi.send(_WorkerProgress(done, total)),
      onPayload: (payload) => toUi.send(_WorkerPayload(payload)),
    );
    toUi.send(_WorkerFinished(frameCount: report.frames));
  } on Object catch (error) {
    toUi.send(_WorkerFinished(frameCount: 0, failure: '$error'));
  }
}

/// Runs the decoder in a worker isolate.
Future<ImageScanReport> _scanInWorker(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
  void Function(String payload)? onPayload,
  bool Function()? isCancelled,
}) async {
  final fromWorker = ReceivePort();
  final Isolate worker;
  try {
    worker = await Isolate.spawn<List<Object?>>(
      _decodeWorker,
      <Object?>[fromWorker.sendPort, bytes],
      debugName: 'qrs-image-scan',
      onError: fromWorker.sendPort,
      errorsAreFatal: true,
    );
  } on Object {
    // Isolates are unavailable in this environment after all; decode in place.
    fromWorker.close();
    return decodeImageForQrPayloads(
      bytes,
      onProgress: onProgress,
      onPayload: onPayload,
      isCancelled: isCancelled,
    );
  }

  final completer = Completer<ImageScanReport>();
  final payloads = <String>[];
  var frames = 0;
  Timer? cancelPoll;
  late final StreamSubscription<Object?> subscription;

  void cleanUp() {
    cancelPoll?.cancel();
    cancelPoll = null;
    worker.kill(priority: Isolate.beforeNextEvent);
    subscription.cancel();
    fromWorker.close();
  }

  void complete(ImageScanReport report) {
    if (completer.isCompleted) return;
    completer.complete(report);
    cleanUp();
  }

  void completeWithError(Object error) {
    if (completer.isCompleted) return;
    completer.completeError(error);
    cleanUp();
  }

  subscription = fromWorker.listen((message) {
    // With `onError` wired to the same port an uncaught worker error arrives as
    // the `[error, stackTrace]` list.
    if (message is List) {
      completeWithError(StateError('Image scan failed: ${message.first}'));
      return;
    }

    switch (message) {
      case _WorkerProgress(:final done, :final total):
        // Remember the frame count so a cancelled scan can still report how
        // many frames the image had.
        frames = total;
        onProgress?.call(done, total);
      case _WorkerPayload(:final payload):
        payloads.add(payload);
        onPayload?.call(payload);
      case _WorkerFinished(:final frameCount, :final failure):
        if (failure != null) {
          completeWithError(FormatException(failure));
        } else {
          complete(ImageScanReport(frames: frameCount, payloads: payloads));
        }
    }
  });
  if (isCancelled != null) {
    // Polling from the UI isolate keeps the worker free of a control channel;
    // whatever decoded before the kill is still reported.
    cancelPoll = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!isCancelled()) return;
      worker.kill(priority: Isolate.immediate);
      complete(ImageScanReport(frames: frames, payloads: payloads));
    });
  }

  return completer.future;
}

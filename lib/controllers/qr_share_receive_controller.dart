import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

import '../share/image_qr_scan.dart';
import '../share/share_document.dart';
import '../share/share_import.dart';
import '../signals/locale.dart';
import '../utils/transfer_rate.dart';

part 'qr_share_receive_actions.dart';
part 'qr_share_receive_settings.dart';

/// The receive page's state: feeds payloads into a [ReceiveSession], follows
/// its progress and turns a completed transfer into a [ShareDocument].
///
/// Every dependency is injected, so tests drive camera frames, a worker-free
/// scanner, the importer and the clock without a plugin or an isolate.
class QrShareReceiveController {
  /// Creates a controller; [cameraAvailable] defaults to the platform table.
  QrShareReceiveController({
    bool? cameraAvailable,
    ShareImporter? importer,
    this.showMessage,
    ImageScanner? imageScanner,
    int Function()? nowMicros,
  }) : cameraAvailable = cameraAvailable ?? platformHasCamera(),
       _importer = importer ?? ShareImporter.defaults,
       _imageScanner = imageScanner ?? scanImageForQrPayloads,
       _rate = TransferRateMeter(nowMicros: nowMicros);

  /// Whether `mobile_scanner` has a camera backend on this platform.
  final bool cameraAvailable;

  /// Reports a user-visible outcome; the page shows it in a snackbar.
  final void Function(String message)? showMessage;

  /// The receiving session that owns the fountain decoder.
  final ReceiveSession _session = ReceiveSession();

  // The transfer: blocks needed and decoded, accepted frames, the per-block
  // status (`1` decoded, the pending degree, `0` unknown), and the share once
  // the transfer completes.
  final k = signal<int>(0);
  final decoded = signal<int>(0);
  final frames = signal<int>(0);
  final status = signal<List<int>>(const <int>[]);
  final share = signal<ShareDocument?>(null);

  // The page's feedback and controls: a localized error, the measured speed,
  // the camera pace, the image scan's progress, the save flags.
  final error = signal<String?>(null);
  final speed = signal<double>(0);
  final pace = signal<ScanPace>(ScanPace.balanced);
  final imageProgress = signal<({int done, int total})?>(null);
  final saving = signal<bool>(false);
  final saved = signal<bool>(false);

  final ShareImporter _importer;
  final ImageScanner _imageScanner;
  final TransferRateMeter _rate;

  int _acceptedFrames = 0;
  int _checksum = 0;

  /// Bumped by [reset] and by [scanImage], so a stale image scan cannot feed a
  /// session the user already forgot.
  int _imageScan = 0;

  double? _summarySpeed;
  bool _disposed = false;

  /// Feeds one raw QR payload into the session.
  ///
  /// Transient outcomes (empty, invalid, duplicate) are silent: a camera sees
  /// non-Yukari QR codes constantly, and each one must not raise an error.
  ScanOutcome addPayload(String? raw) {
    if (_disposed || raw == null || raw.isEmpty) return ScanOutcome.empty;

    final transferInProgress =
        frames.value > 0 && share.value == null && !_session.isComplete;
    final ScanOutcome result;
    try {
      result = _session.addScan(raw);
    } on Object {
      return ScanOutcome.invalid;
    }

    // A frame whose checksum differs belongs to another transfer. Detecting it
    // from the checksum instead of [ScanOutcome.started] also covers a
    // one-block share, whose first frame starts *and* completes the transfer.
    if (_session.checksum != _checksum) {
      _checksum = _session.checksum;
      _forgetRate();
      share.value = null;
      if (transferInProgress) {
        showMessage?.call(l10n.value.shareReceiveDifferentShare);
      }
    }
    if (result == ScanOutcome.complete) _complete();
    _sync();
    return result;
  }

  /// Forgets the current transfer, e.g. to scan another share.
  void reset() {
    if (_disposed) return;
    _session.reset();
    _checksum = 0;
    _imageScan++; // cancels an image scan still feeding the session
    _forgetRate();
    share.value = null;
    error.value = null;
    imageProgress.value = null;
    saved.value = false;
    _sync();
  }

  /// Reads the share a completed transfer carries.
  void _complete() {
    final result = _session.result;
    if (result == null) return;

    final document = _documentOf(result);
    error.value = document == null ? l10n.value.shareReceiveInvalid : null;
    share.value = document;
    unawaited(HapticFeedback.mediumImpact());
  }

  /// The share [result] carries, or null when it is not a Yukari share.
  ShareDocument? _documentOf(ReceiveResult result) {
    // The metadata is written by the sender, so the content type is the only
    // thing that says "this transfer is a Yukari share" before the JSON is
    // trusted; ShareDocument.decode then validates every field.
    if (result.meta.contentType != shareContentType) return null;
    // A share is already rejected for this by decode; checking before the
    // decode keeps a hostile multi-MB transfer from being decoded first.
    if (result.data.length > shareMaxBytes) return null;
    try {
      return ShareDocument.decode(utf8.decode(result.data));
    } on Object {
      return null;
    }
  }

  /// Mirrors the session into the signals, touching each only when it changed.
  void _sync() {
    final blocks = _session.blockStatus;
    if (k.value != _session.k) k.value = _session.k;
    if (decoded.value != _session.decodedCount) {
      decoded.value = _session.decodedCount;
    }
    if (frames.value != _session.encodedCount) {
      frames.value = _session.encodedCount;
    }
    if (!listEquals(status.value, blocks)) status.value = blocks;

    // Accepted frames only: a repeated frame carries no new payload, and the
    // reading then ages out of the window while the camera keeps showing it.
    final accepted = _session.encodedCount - _acceptedFrames;
    _acceptedFrames = _session.encodedCount;
    if (accepted > 0) {
      // A frame header carries the payload size and the block count, so
      // `bytes / k` is the mean original block size.
      final perFrame = _session.k == 0
          ? 0
          : (_session.bytes / _session.k).round();
      _rate.record(accepted * perFrame);
    }

    // A finished transfer has no "current" rate; the meter turns its payload
    // and duration into the average that stays true.
    if (_summarySpeed == null && _session.isComplete) {
      _summarySpeed = _rate.averageBytesPerSecond(_session.bytes);
    }
    final nextSpeed = _summarySpeed ?? _rate.bytesPerSecond;
    if (speed.value != nextSpeed) speed.value = nextSpeed;
  }

  /// Drops the rate history of the transfer that just ended.
  void _forgetRate() {
    _rate.clear();
    _acceptedFrames = 0;
    _summarySpeed = null;
  }

  /// Frees the signals this controller owns.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    k.dispose();
    decoded.dispose();
    frames.dispose();
    status.dispose();
    share.dispose();
    error.dispose();
    speed.dispose();
    pace.dispose();
    imageProgress.dispose();
    saving.dispose();
    saved.dispose();
  }
}

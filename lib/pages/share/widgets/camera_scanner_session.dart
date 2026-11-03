import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../controllers/qr_share_receive_controller.dart';

/// The scanner throttle [pace] asks for.
///
/// [DetectionSpeed.normal] uses mobile_scanner's 250 ms detection timeout, so
/// the camera analyzes about four frames a second; [DetectionSpeed.noDuplicates]
/// analyzes every frame and reports each code once; [DetectionSpeed.unrestricted]
/// removes the throttle entirely. The trade-off is battery and heat against how
/// many frames per second the receiver gets to see.
DetectionSpeed detectionSpeedFor(ScanPace pace) => switch (pace) {
  ScanPace.relaxed => DetectionSpeed.normal,
  ScanPace.balanced => DetectionSpeed.noDuplicates,
  ScanPace.turbo => DetectionSpeed.unrestricted,
};

/// Keeps the receive page's camera alive across a [ScanPace] change.
///
/// `MobileScannerPlatform` is a process-wide singleton holding one camera
/// texture: `start()` throws `controllerAlreadyInitialized` while that texture
/// is taken, `stop()` releases it and `dispose()` releases it one
/// method-channel round trip late. A new pace therefore cannot build its
/// scanner beside the old one. Every call is serialized on one queue and a new
/// pace waits until the previous scanner released the camera before it builds
/// and starts its own.
class CameraScannerSession {
  /// Creates a session that starts on [pace] and builds its scanners with the
  /// injected factory.
  CameraScannerSession(this._create, {required ScanPace pace})
    : _pace = pace,
      _wanted = pace;

  final MobileScannerController Function(ScanPace pace) _create;

  ScanPace _pace;
  ScanPace _wanted;

  MobileScannerController? _scanner;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  /// Called whenever [scanner] changes, so the UI can render the current one.
  VoidCallback? onChanged;

  /// The scanner of the current pace, or null while a swap is in flight.
  MobileScannerController? get scanner => _scanner;

  /// Completes when every queued call has finished.
  @visibleForTesting
  Future<void> get settled => _queue;

  /// Starts the camera of the current pace.
  Future<void> start() => _append(_startScanner);

  /// Stops the camera but keeps the scanner, for the app losing the foreground.
  Future<void> stop() => _append(_stopScanner);

  /// Runs [action] on the current scanner, if there is one to run it on.
  Future<void> withScanner(
    Future<void> Function(MobileScannerController scanner) action,
  ) => _append(() async {
    final scanner = _scanner;
    if (scanner != null) await action(scanner);
  });

  /// Switches to [pace] behind the calls already queued.
  void request(ScanPace pace) {
    _wanted = pace;
    _append(_swap);
  }

  /// Releases the camera for good and drops every call still queued.
  Future<void> dispose() {
    _disposed = true;
    return _append(_disposeScanner);
  }

  /// Chains [step] behind everything queued so far.
  ///
  /// The queue continues past a failure, because the scanner's own state
  /// already tells the user a camera refused to start, and a call that throws
  /// must not wedge the calls behind it.
  Future<void> _append(Future<void> Function() step) {
    _queue = _queue.then((_) => step()).catchError((Object _) {});
    return _queue;
  }

  /// Builds the scanner of the wanted pace and starts it.
  Future<void> _startScanner() async {
    if (_disposed) return;

    var scanner = _scanner;
    if (scanner == null) {
      _pace = _wanted;
      scanner = _scanner = _create(_pace);
      onChanged?.call();
    }
    if (scanner.value.isRunning) return;
    // The scanner starts before its MobileScanner mounts, so the plugin waits
    // up to 500 ms for the widget to attach. A slower frame than that is
    // accepted: the next lifecycle or pace event starts the camera again.
    await scanner.start();
  }

  Future<void> _stopScanner() async {
    final scanner = _scanner;
    if (scanner != null && scanner.value.isRunning) await scanner.stop();
  }

  /// Replaces the scanner with one for the pace the last request asked for.
  Future<void> _swap() async {
    if (_disposed) return;

    final pace = _wanted;
    if (pace == _pace && _scanner != null) return;

    // The next scanner cannot start while this one still holds the texture.
    await _disposeScanner();
    if (_disposed) return;

    _pace = pace;
    _scanner = _create(pace);
    onChanged?.call();
    await _startScanner();
  }

  Future<void> _disposeScanner() async {
    final scanner = _scanner;
    if (scanner == null) return;

    // Drop the scanner before touching the platform: nothing may start it
    // again while it shuts down, and the UI must stop rendering it.
    _scanner = null;
    onChanged?.call();

    // Neither a refused stop nor a refused dispose may escape: the platform
    // released the camera texture either way, so the next scanner can take it,
    // and aborting here would strand the preview on a dead one.
    try {
      if (scanner.value.isRunning) await scanner.stop();
    } on Object {
      // The platform may have released the camera first.
    }
    try {
      await scanner.dispose();
    } on Object {
      // Closing what is left of the scanner is best effort.
    }
  }
}

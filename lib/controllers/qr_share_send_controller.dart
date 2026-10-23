import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

import '../share/share_bundle.dart';
import '../share/share_document.dart';

part 'qr_share_send_gif.dart';
part 'qr_share_send_settings.dart';

/// Drives the sender half of "Share via QR": the fountain-coded stream of masked
/// [ShareDocument]s, its playback and settings, and the GIF export.
class QrShareSendController {
  QrShareSendController({
    required this.documents,
    required double refreshRate,
    this.random,
  }) : fps = signal(defaultShareFps(refreshRate)) {
    _rebuild();
  }

  /// The masked documents being streamed, never empty: the page reports a
  /// target it cannot resolve instead of opening a sender.
  final List<ShareDocument> documents;

  /// The fountain's randomness source; null draws a fresh one.
  final Random? random;

  /// The frame on screen; the constructor publishes the first one.
  final Signal<SendFrame?> frame = signal(null);

  final Signal<bool> playing = signal(false);

  /// Frames per second the stream is paced at.
  final Signal<int> fps;

  /// The block size the stream uses; changing it restarts the transfer.
  ///
  /// Starts at Easy: a masked share document is well under 1 KiB, so even Easy
  /// is only a frame or three, and its larger modules scan from farther away.
  final Signal<QrShareDensity> density = signal(QrShareDensity.easy);

  /// Frames published so far, the preview frame included.
  final Signal<int> framesSent = signal(0);

  final Signal<int> blockCount = signal(0);

  /// Payload bytes on the wire, after compression.
  final Signal<int> payloadBytes = signal(0);

  /// Whether a GIF export is running, and how many of its frames are written.
  final Signal<bool> exporting = signal(false);
  final Signal<int> exported = signal(0);

  late final Uint8List _payload = Uint8List.fromList(
    utf8.encode(encodeShareItems(documents)),
  );

  /// The deflated transfer size the density presets split.
  late final int _compressedBytes = _compressedTransferBytes(_payload);

  /// Whether the whole share fits one code at the borderline preset.
  ///
  /// The preset is fixed, so this never changes and is a plain field.
  late final bool staticShare = fitsOneShareCode(_compressedBytes);

  /// The block size the session slices with: a static share sends its whole
  /// payload as one block.
  int get _sliceSize => staticShare
      ? _compressedBytes
      : density.value.sliceSizeFor(_compressedBytes);

  late SendSession _session;
  Timer? _timer;
  Timer? _preRenderTimer;
  SendFrame? _preRendered;
  bool _disposed = false;
  bool _exportCancelled = false;

  /// The session being streamed; the GIF export sends what it sends.
  @visibleForTesting
  SendSession get session => _session;

  Duration get _frameInterval => Duration(
    microseconds: (Duration.microsecondsPerSecond / fps.value).round(),
  );

  /// Publishes the first frame, or the new session's preview after a rebuild.
  void _rebuild() {
    _cancelPreRender();
    _session = SendSession.forFile(
      _payload,
      filename: _shareFileName,
      contentType: shareContentType,
      sliceSize: _sliceSize,
      // Always on: the document is JSON text, which zlib roughly halves, and a
      // switch would only ever be turned off by mistake.
      compress: true,
      random: random,
      prefix: '',
    );
    framesSent.value = 0;
    blockCount.value = _session.blockCount;
    payloadBytes.value = _session.payloadBytes;
    _publish();
  }

  /// Puts the next frame on screen: it is usually already encoded, so the
  /// encode cost never delays a tick.
  void _publish() {
    if (_disposed) return;
    frame.value = _preRendered ?? _session.next();
    _preRendered = null;
    framesSent.value = framesSent.value + 1;
    if (playing.value) _preRender();
  }

  /// Encodes the next frame in its own event-loop turn, so it overlaps the
  /// paint of the frame on screen instead of delaying the frame timer.
  void _preRender() {
    _preRenderTimer?.cancel();
    _preRenderTimer = Timer(Duration.zero, () {
      _preRenderTimer = null;
      if (_disposed) return;
      _preRendered = _session.next();
    });
  }

  void _cancelPreRender() {
    _preRenderTimer?.cancel();
    _preRenderTimer = null;
    _preRendered = null;
  }

  /// Starts the frame loop, unless there is nothing to animate.
  ///
  /// A static share's first frame already carries the whole payload, so playing
  /// it would only repaint an identical code.
  void play() {
    if (_disposed || staticShare || playing.value) return;
    playing.value = true;
    if (_preRendered == null) _preRender();
    _armTimer(_frameInterval);
  }

  /// Stops the frame loop and cancels a pre-render that has not run yet.
  ///
  /// A frame that is already encoded is kept, so resuming publishes it at once.
  void pause() {
    if (_disposed || !playing.value) return;
    playing.value = false;
    _timer?.cancel();
    _timer = null;
    _preRenderTimer?.cancel();
    _preRenderTimer = null;
  }

  void toggle() {
    if (_disposed) return;
    playing.value ? pause() : play();
  }

  /// Applies [value] clamped to [minShareFps]..[maxShareFps]; the armed timer
  /// is re-armed at once so the new rate applies to the next frame.
  ///
  /// A static share keeps its rate: it has no stream to pace, so the control is
  /// not offered and the value stays the one it opened with.
  void updateFps(int value) {
    if (_disposed || staticShare) return;
    final clamped = value.clamp(minShareFps, maxShareFps).toInt();
    if (clamped == fps.value) return;
    fps.value = clamped;
    if (playing.value) _armTimer(_frameInterval);
  }

  /// Restarts the stream with [value]'s block size, keeping the playback state.
  ///
  /// A static share keeps [density] and its one block: no preset can split a
  /// payload that fits a single code.
  void updateDensity(QrShareDensity value) {
    if (_disposed || staticShare || value == density.value) return;
    density.value = value;
    _rebuild();
    if (playing.value) _armTimer(_frameInterval);
  }

  void _armTimer(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _onTick);
  }

  /// Publishes a frame and re-arms with the interval minus the time the tick
  /// took, so per-frame work never accumulates into the cadence.
  void _onTick() {
    if (_disposed) return;
    final stopwatch = Stopwatch()..start();
    _publish();
    final remaining = _frameInterval - stopwatch.elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _onTick);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _cancelPreRender();
    for (final signal in <ReadonlySignal<Object?>>[
      frame,
      playing,
      fps,
      density,
      framesSent,
      blockCount,
      payloadBytes,
      exporting,
      exported,
    ]) {
      signal.dispose();
    }
  }
}

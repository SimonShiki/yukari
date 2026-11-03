part of 'qr_share_send_controller.dart';

/// The sender's opt-in extras: adding this device as a peer, and sharing the
/// network's non-essential config.
///
/// A toggle re-resolves the share it is streaming, so what the summary says and
/// what the QR codes carry can never disagree.
extension QrShareSendOptions on QrShareSendController {
  /// Whether the share carries this device as a peer.
  void setIncludeSelf(bool value) => _choose(
    available: selfPeerAvailable,
    option: includeSelf,
    value: value,
    options: (includeSelf: value, includeConfigs: includeConfigs.value),
  );

  /// Whether the share carries the network's non-essential config.
  void setIncludeConfigs(bool value) => _choose(
    available: configsAvailable,
    option: includeConfigs,
    value: value,
    options: (includeSelf: includeSelf.value, includeConfigs: value),
  );

  /// Re-resolves the share for [options] and restarts the stream.
  ///
  /// Nothing moves when [option] is already in that state, cannot be offered at
  /// all, no resolver can serve it, or a GIF export owns the frame loop: an
  /// export encodes the session it started with, so replacing that session
  /// mid-run would write a half-and-half GIF.
  void _choose({
    required bool available,
    required Signal<bool> option,
    required bool value,
    required ShareOptions options,
  }) {
    final resolve = this.resolve;
    if (_disposed || resolve == null || exporting.value) return;
    if (!available || option.value == value) return;

    final target = resolve(options);
    // A target that lost its peer in between has nothing to switch to; the
    // stream on screen keeps running rather than going blank.
    if (target.documents.isEmpty) return;

    option.value = value;
    documents.value = target.documents;
    _restart();
  }
}

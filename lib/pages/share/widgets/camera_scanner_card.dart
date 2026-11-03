import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';
import 'camera_scanner_error.dart';
import 'camera_scanner_session.dart';

/// The camera preview and QR detection of the receive page.
///
/// mobile_scanner fixes the detection speed when its controller is constructed,
/// so a new [pace] needs a new controller — but the plugin also holds one camera
/// texture for the whole process, which a new controller cannot take from the
/// old one. The card therefore swaps its own scanner through
/// [CameraScannerSession] instead of being re-keyed around it.
class CameraScannerCard extends StatefulWidget {
  /// Creates the camera card for [controller].
  const CameraScannerCard({
    super.key,
    required this.controller,
    this.pace = ScanPace.balanced,
  });

  /// The receive controller every scanned payload goes to.
  final QrShareReceiveController controller;

  /// How hard the scanner works for frames.
  final ScanPace pace;

  @override
  State<CameraScannerCard> createState() => _CameraScannerCardState();
}

class _CameraScannerCardState extends State<CameraScannerCard>
    with WidgetsBindingObserver {
  late final CameraScannerSession _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = CameraScannerSession(_createScanner, pace: widget.pace)
      ..onChanged = _onScannerChanged;
    unawaited(_session.start());
  }

  /// mobile_scanner only follows the app lifecycle for a controller it owns, so
  /// the card stops the camera while the app is in the background and starts it
  /// again when the user comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        unawaited(_session.stop());
      case AppLifecycleState.resumed:
        unawaited(_session.start());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void didUpdateWidget(CameraScannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pace != widget.pace) _session.request(widget.pace);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_session.dispose());
    super.dispose();
  }

  void _onScannerChanged() {
    if (mounted) setState(() {});
  }

  MobileScannerController _createScanner(ScanPace pace) {
    return MobileScannerController(
      // ML Kit wants 1280x720 or 1920x1080 input and at least two pixels per QR
      // module; 720p keeps the per-frame decode cost low enough to follow a
      // 15 fps stream on a phone.
      cameraResolution: const Size(1280, 720),
      detectionSpeed: detectionSpeedFor(pace),
      formats: const [BarcodeFormat.qrCode],
      // The session decides when the camera may start, once the previous
      // scanner released it.
      autoStart: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final scanner = _session.scanner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: scanner == null
                // The first scanner waits for the widget to attach, and a new
                // pace waits for the previous scanner to release the camera.
                ? ColoredBox(color: colors.surfaceContainerHighest)
                : MobileScanner(
                    key: ObjectKey(scanner),
                    controller: scanner,
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        widget.controller.addPayload(barcode.rawValue);
                      }
                    },
                    errorBuilder: (context, error) =>
                        CameraScannerErrorPane(error: error),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.shareReceiveCameraHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            // The buttons follow whichever scanner the session currently owns,
            // so a pace change must not leave them on the old one.
            if (scanner != null)
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: scanner,
                builder: (context, state, _) => Row(
                  children: [
                    IconButton(
                      tooltip: l10n.shareReceiveTorch,
                      onPressed: state.torchState == TorchState.unavailable
                          ? null
                          : () => unawaited(_session.withScanner(_toggleTorch)),
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.shareReceiveSwitchCamera,
                      onPressed: () =>
                          unawaited(_session.withScanner(_switchCamera)),
                      icon: const Icon(Icons.cameraswitch_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggleTorch(MobileScannerController scanner) async {
    try {
      await scanner.toggleTorch();
    } on Object {
      // The platform can refuse the torch; the next state read tells the user.
    }
  }

  Future<void> _switchCamera(MobileScannerController scanner) async {
    try {
      await scanner.switchCamera();
    } on Object {
      // A single-camera device has nothing to switch to.
    }
  }
}

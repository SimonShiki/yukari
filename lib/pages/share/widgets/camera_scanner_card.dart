import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';

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

/// The camera preview and QR detection of the receive page.
///
/// The card must be re-keyed when [pace] changes: mobile_scanner fixes the
/// detection speed when its controller is constructed, so a new pace needs a new
/// card and a new controller. The page keys it by the pace.
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
  late final MobileScannerController _scanner = MobileScannerController(
    // ML Kit wants 1280x720 or 1920x1080 input and at least two pixels per QR
    // module; 720p keeps the per-frame decode cost low enough to follow a
    // 15 fps stream on a phone.
    cameraResolution: const Size(1280, 720),
    detectionSpeed: detectionSpeedFor(widget.pace),
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(CameraScannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.pace == widget.pace,
      'Re-key CameraScannerCard when the pace changes',
    );
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
        if (_scanner.value.isRunning) unawaited(_stopCamera());
      case AppLifecycleState.resumed:
        if (!_scanner.value.isRunning) unawaited(_startCamera());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      await _scanner.stop();
    } on Object {
      // The platform may have released the camera first.
    }
  }

  Future<void> _startCamera() async {
    try {
      await _scanner.start();
    } on Object {
      // A denied permission keeps the preview in its error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(
              controller: _scanner,
              fit: BoxFit.cover,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  widget.controller.addPayload(barcode.rawValue);
                }
              },
              errorBuilder: (context, error) => ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.no_photography_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _describe(error),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scanner,
              builder: (context, state, _) => Row(
                children: [
                  IconButton(
                    tooltip: l10n.shareReceiveTorch,
                    onPressed: state.torchState == TorchState.unavailable
                        ? null
                        : _toggleTorch,
                    icon: Icon(
                      state.torchState == TorchState.on
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.shareReceiveSwitchCamera,
                    onPressed: _switchCamera,
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

  /// A camera failure in words: the code, and the plugin's detail when it has
  /// one. Without this the preview would just stay black.
  String _describe(MobileScannerException error) {
    final details = error.errorDetails?.message;
    return details == null || details.isEmpty
        ? error.errorCode.name
        : '${error.errorCode.name}\n$details';
  }

  Future<void> _toggleTorch() async {
    try {
      await _scanner.toggleTorch();
    } on Object {
      // The platform can refuse the torch; the next state read tells the user.
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scanner.switchCamera();
    } on Object {
      // A single-camera device has nothing to switch to.
    }
  }
}

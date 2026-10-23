import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/qr_share_receive_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'widgets/camera_scanner_card.dart';
import 'widgets/receive_progress_card.dart';
import 'widgets/receive_states.dart';
import 'widgets/share_page_body.dart';
import 'widgets/share_preview_card.dart';

/// The receiving half of "Share via QR": scans the other device's fountain
/// frames — from the camera on Android, or from a picked screenshot or GIF on
/// every platform — shows the transfer live, and adds the network or saves the
/// node at the end.
class QrShareReceivePage extends StatefulWidget {
  /// Creates the receive page.
  const QrShareReceivePage({
    super.key,
    this.controller,
    this.cameraBuilder,
    this.pickImage,
  });

  /// Injected by tests; the page creates and disposes its own otherwise. The
  /// controller owns the platform's camera decision and every message sink.
  final QrShareReceiveController? controller;

  /// Replaces the camera pane and receives the current scan pace, so a test can
  /// assert the pace the card is asked to scan with. The default card is never
  /// built by widget tests, which keeps the plugin out of them.
  final Widget Function(BuildContext context, ScanPace pace)? cameraBuilder;

  /// Picks the image to scan; the page opens the platform picker otherwise.
  final Future<Uint8List?> Function()? pickImage;

  @override
  State<QrShareReceivePage> createState() => _QrShareReceivePageState();
}

class _QrShareReceivePageState extends State<QrShareReceivePage> {
  late final QrShareReceiveController _controller =
      widget.controller ??
      QrShareReceiveController(
        // A save or a different share can finish after the user left; the
        // message then has no page to show it on.
        showMessage: (message) {
          if (mounted) showAppSnackBar(context, message);
        },
      );

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// Picks an image or GIF and feeds it to the receiver.
  Future<void> _scanPickedImage() async {
    try {
      final bytes = await (widget.pickImage ?? _pickImage)();
      if (bytes == null) return;
      await _controller.scanImage(bytes);
    } on Object catch (error) {
      // The picker itself failed, before the controller could report anything.
      if (mounted) {
        showAppSnackBar(
          context,
          context.l10n.shareReceiveImageFailed('$error'),
        );
      }
    }
  }

  /// Opens the platform picker on an image, including the animated GIF the
  /// share page exports.
  Future<Uint8List?> _pickImage() async {
    final file = await FilePicker.pickFile(
      dialogTitle: context.l10n.shareReceiveScanImage,
      type: FileType.image,
    );
    return file?.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shareReceiveTitle),
        actions: [
          SignalBuilder(
            builder: (context) {
              final started =
                  _controller.shares.value.isNotEmpty ||
                  _controller.frames.value > 0;
              if (!started) return const SizedBox.shrink();
              return IconButton(
                tooltip: l10n.shareReceiveScanAnother,
                onPressed: _controller.reset,
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SharePageBody(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SignalBuilder(builder: _content),
        ),
      ),
    );
  }

  /// The camera, the live transfer and the completed preview, one at a time.
  ///
  /// Only the page's layout states are read here, so neither the camera card
  /// nor the progress card rebuilds because the other one changed.
  Widget _content(BuildContext context) {
    final shares = _controller.shares.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shares.isEmpty) ...[
          _cameraPane(context),
          const SizedBox(height: 16),
          ReceiveErrorBanner(controller: _controller),
          ReceiveProgressCard(
            controller: _controller,
            cameraAvailable: _controller.cameraAvailable,
            onScanImage: _scanPickedImage,
          ),
        ] else
          SharePreviewCard(shares: shares, controller: _controller),
      ],
    );
  }

  /// The camera preview, a stub in widget tests, or the fallback explanation.
  Widget _cameraPane(BuildContext context) {
    if (!_controller.cameraAvailable) return const NoCameraCard();
    final builder = widget.cameraBuilder;

    // The card rebuilds its own scanner for a new pace: mobile_scanner fixes
    // the detection speed when its controller is built, and it holds one
    // process-wide camera texture a new controller cannot take over. An
    // injected builder gets the same pace, which is how tests see it.
    return SignalBuilder(
      builder: (context) {
        final pace = _controller.pace.value;
        if (builder != null) return builder(context, pace);
        return CameraScannerCard(controller: _controller, pace: pace);
      },
    );
  }
}

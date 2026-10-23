import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_send_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/byte_units.dart';
import '../../../widgets/card_surface/card_surface.dart';
import 'qr_matrix_view.dart';

/// The widest the code draws, in logical pixels: at this size a phone camera
/// resolves the modules from a comfortable distance.
const double _maxQrSize = 420;

/// The live QR stream: the current fountain frame, the playback control, the
/// frame statistics and how to hold the other device.
class QrStreamCard extends StatelessWidget {
  const QrStreamCard({super.key, required this.controller});

  final QrShareSendController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QrFrame(controller: controller),
            const SizedBox(height: 12),
            if (controller.staticShare)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stats(context, TextAlign.start),
                  Text(
                    l10n.shareQrFps(controller.fps.peek()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  SignalBuilder(
                    builder: (context) {
                      final playing = controller.playing.value;
                      return IconButton.filledTonal(
                        tooltip: playing ? l10n.shareQrPause : l10n.shareQrPlay,
                        onPressed: controller.toggle,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _stats(context, TextAlign.end)),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              l10n.shareQrHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The frame statistics line, which follows every frame the card shows.
  Widget _stats(BuildContext context, TextAlign align) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) => Text(
        l10n.shareQrFrameStats(
          controller.framesSent.value,
          controller.blockCount.value,
          formatBytes(controller.payloadBytes.value),
        ),
        textAlign: align,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The frame on screen, on the white surface a camera needs.
class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.controller});

  final QrShareSendController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) {
        final frame = controller.frame.value;
        final sent = controller.framesSent.value;
        if (frame == null) {
          final colors = Theme.of(context).colorScheme;
          return AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.qr_code_2,
                  size: 72,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Semantics(
          image: true,
          label: l10n.shareQrFrameSemanticLabel(sent),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _maxQrSize,
                maxHeight: _maxQrSize,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                // Black-on-white in both themes: a camera needs that contrast,
                // so the code is never theme-inverted.
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: QrMatrixView(matrix: frame.qr.data),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

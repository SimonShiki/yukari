import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_send_controller.dart';
import '../../../l10n/l10n.dart';

/// The stream's tuning: how fast it plays, how dense each code is, and the GIF
/// export for a receiver without a camera.
class QrStreamSettings extends StatelessWidget {
  const QrStreamSettings({
    super.key,
    required this.controller,
    required this.onExportGif,
  });

  final QrShareSendController controller;

  /// Encodes and saves the stream as an animated GIF.
  final VoidCallback onExportGif;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SignalBuilder(
              builder: (context) {
                final fps = controller.fps.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.shareQrFrameRate,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: M3ESlider(
                            value: fps.toDouble(),
                            min: minShareFps.toDouble(),
                            max: maxShareFps.toDouble(),
                            divisions: maxShareFps - minShareFps,
                            label: l10n.shareQrFps(fps),
                            onChanged: (value) =>
                                controller.updateFps(value.round()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.shareQrFps(fps),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    _supporting(context, l10n.shareQrFrameRateHint),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            SignalBuilder(
              builder: (context) {
                final density = controller.density.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.shareQrDensity,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<QrShareDensity>(
                      showSelectedIcon: false,
                      expandedInsets: EdgeInsets.zero,
                      segments: [
                        ButtonSegment(
                          value: QrShareDensity.easy,
                          label: Text(l10n.shareQrDensityEasy),
                        ),
                        ButtonSegment(
                          value: QrShareDensity.balanced,
                          label: Text(l10n.shareQrDensityBalanced),
                        ),
                        ButtonSegment(
                          value: QrShareDensity.fast,
                          label: Text(l10n.shareQrDensityFast),
                        ),
                      ],
                      selected: {density},
                      onSelectionChanged: (selection) =>
                          controller.updateDensity(selection.single),
                    ),
                    const SizedBox(height: 8),
                    _supporting(context, l10n.shareQrDensityHint),
                    _supporting(context, l10n.shareQrDensityRestart),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context) {
                if (!controller.exporting.value) {
                  return M3EButton.icon(
                    onPressed: onExportGif,
                    icon: const Icon(Icons.gif_box_outlined),
                    label: Text(l10n.shareQrExportGif),
                    style: M3EButtonStyle.tonal,
                  );
                }
                final done = controller.exported.value;
                final total = controller.gifFrameCount;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: total == 0 ? null : done / total,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shareQrGifExporting(done, total),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: controller.cancelExport,
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The quiet explanation under a setting.
  Widget _supporting(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

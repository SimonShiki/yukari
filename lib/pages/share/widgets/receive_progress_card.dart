import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/byte_units.dart';
import 'block_grid.dart';

/// The live transfer: how many blocks are decoded, how fast they arrive, the
/// per-block status picture, and the ways to feed the receiver more frames.
///
/// Each figure has its own [SignalBuilder] so a speed update does not rebuild
/// the block grid and a status update does not rebuild the progress bar.
class ReceiveProgressCard extends StatelessWidget {
  /// Creates the progress card for [controller].
  const ReceiveProgressCard({
    super.key,
    required this.controller,
    required this.cameraAvailable,
    required this.onScanImage,
  });

  /// The receive controller to follow.
  final QrShareReceiveController controller;

  /// Whether the scan-rate selector applies on this platform.
  final bool cameraAvailable;

  /// Opens the image picker and scans what the user picked.
  final VoidCallback onScanImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                final k = controller.k.value;
                final decoded = controller.decoded.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Indeterminate until the first frame says how many blocks
                    // the transfer has.
                    M3ELinearWavyProgressIndicator(
                      value: k == 0 ? null : decoded / k,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      k == 0
                          ? l10n.shareReceiveWaiting
                          : l10n.shareReceiveProgress(decoded, k),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            SignalBuilder(
              builder: (context) => Text(
                l10n.shareReceiveFrames(controller.frames.value),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context) => _SpeedRow(
                label: l10n.shareReceiveSpeed,
                bytesPerSecond: controller.speed.value,
              ),
            ),
            SignalBuilder(
              builder: (context) {
                final k = controller.k.value;
                if (k == 0) return const SizedBox.shrink();
                final decoded = controller.decoded.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: BlockGrid(
                    status: controller.status.value,
                    semanticLabel: l10n.shareReceiveProgress(decoded, k),
                  ),
                );
              },
            ),
            SignalBuilder(
              builder: (context) {
                final progress = controller.imageProgress.value;
                if (progress == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: progress.total == 0
                      // The frame count is unknown until the first frame is
                      // examined; "frame 0 of 0" would be a lie.
                      ? const LinearProgressIndicator(minHeight: 4)
                      : Text(
                          l10n.shareReceiveImageScanning(
                            progress.done,
                            progress.total,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                );
              },
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context) => M3EButton.icon(
                // One image scan at a time: a second tap would start the picker
                // over a scan that is already feeding the session.
                onPressed: controller.imageProgress.value == null
                    ? onScanImage
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.shareReceiveScanImage),
                style: M3EButtonStyle.tonal,
              ),
            ),
            if (cameraAvailable) ...[
              const SizedBox(height: 24),
              SignalBuilder(
                builder: (context) => _ScanRateSelector(controller: controller),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The measured payload rate, with the unit a reader expects.
class _SpeedRow extends StatelessWidget {
  const _SpeedRow({required this.label, required this.bytesPerSecond});

  final String label;
  final double bytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.download_rounded, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          '${formatBytes(bytesPerSecond)}/s',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// How hard the camera is allowed to scan, when this platform has one.
class _ScanRateSelector extends StatelessWidget {
  const _ScanRateSelector({required this.controller});

  final QrShareReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.shareReceiveScanRate, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ScanPace>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: [
            ButtonSegment(
              value: ScanPace.relaxed,
              label: Text(l10n.shareReceiveRateRelaxed),
            ),
            ButtonSegment(
              value: ScanPace.balanced,
              label: Text(l10n.shareReceiveRateBalanced),
            ),
            ButtonSegment(
              value: ScanPace.turbo,
              label: Text(l10n.shareReceiveRateTurbo),
            ),
          ],
          selected: {controller.pace.value},
          onSelectionChanged: (selection) =>
              controller.pace.value = selection.single,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.shareReceiveRateHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

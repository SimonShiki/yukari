import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The error pane of the camera preview.
///
/// A refused camera would otherwise leave the preview black, so the pane names
/// the plugin's error code and, when the plugin has one, its detail.
class CameraScannerErrorPane extends StatelessWidget {
  /// Creates the pane for [error].
  const CameraScannerErrorPane({super.key, required this.error});

  /// The failure the preview reported.
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = error.errorDetails?.message;

    return ColoredBox(
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
                details == null || details.isEmpty
                    ? error.errorCode.name
                    : '${error.errorCode.name}\n$details',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

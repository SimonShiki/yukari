import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';

/// What the receive page shows where a camera would be on a platform without
/// one.
///
/// It only explains the fallback: the progress card's image scan is the single
/// scan action on every platform, so there is no second button here.
class NoCameraCard extends StatelessWidget {
  /// Creates the fallback explanation.
  const NoCameraCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.no_photography_outlined, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.shareReceiveNoCamera,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The localized failure of the current scan, or nothing when it is fine.
///
/// The card offers [QrShareReceiveController.reset], which forgets the transfer
/// that failed so the user can scan again.
class ReceiveErrorBanner extends StatelessWidget {
  /// Creates the banner for [controller].
  const ReceiveErrorBanner({super.key, required this.controller});

  /// The receive controller whose error it shows.
  final QrShareReceiveController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final message = controller.error.value;
      if (message == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _card(context, message),
      );
    },
  );

  Widget _card(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: controller.reset,
              child: Text(context.l10n.shareReceiveScanAnother),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// The width a dialog's content is limited to: narrow on phones, and never a
/// wall of fields on a wide window.
double dialogContentWidth(BuildContext context) =>
    math.min(MediaQuery.sizeOf(context).width * 0.8, 560);

/// Asks the user to confirm an action, and answers whether they did.
///
/// A dismissal and the cancel button both answer no. A [destructive] confirm
/// is coloured with the theme's error pair, matching the row menu that offers
/// it; every other confirm is a normal filled button. [cancelLabel] defaults
/// to the shared "Cancel".
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(icon),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel ?? context.l10n.commonCancel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ) ??
    false;

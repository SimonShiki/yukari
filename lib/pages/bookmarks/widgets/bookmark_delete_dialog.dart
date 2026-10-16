import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/dialog/confirm_dialog.dart';

/// Confirms deleting [bookmark]; false when the dialog is dismissed.
Future<bool> showBookmarkDeleteDialog(
  BuildContext context,
  Bookmark bookmark,
) => showConfirmDialog(
  context,
  icon: Icons.delete_outline,
  title: context.l10n.bookmarksDeleteConfirm(bookmark.displayName),
  message: context.l10n.bookmarksDeleteConfirmDescription,
  confirmLabel: context.l10n.commonDelete,
  destructive: true,
);

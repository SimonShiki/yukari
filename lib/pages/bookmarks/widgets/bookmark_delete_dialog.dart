import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';
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

/// Confirms deleting every bookmark in [bookmarks] with one question; a single
/// bookmark keeps the wording that names it.
Future<bool> showBookmarksDeleteDialog(
  BuildContext context,
  List<Bookmark> bookmarks,
) => bookmarks.length == 1
    ? showBookmarkDeleteDialog(context, bookmarks.single)
    : showConfirmDialog(
        context,
        icon: Icons.delete_outline,
        title: context.l10n.bookmarksDeleteSelected(bookmarks.length),
        message: context.l10n.bookmarksDeleteSelectedDescription,
        confirmLabel: context.l10n.commonDelete,
        destructive: true,
      );

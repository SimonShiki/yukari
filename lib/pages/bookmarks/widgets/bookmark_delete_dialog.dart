import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';

/// Confirms deleting [bookmark]; false when the dialog is dismissed.
Future<bool> showBookmarkDeleteDialog(
  BuildContext context,
  Bookmark bookmark,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(context.l10n.bookmarksDeleteConfirm(bookmark.displayName)),
        content: Text(context.l10n.bookmarksDeleteConfirmDescription),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    ) ??
    false;

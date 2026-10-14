import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';

/// Asks whether [bookmark] should leave the list, and answers false when the
/// user dismisses the dialog.
Future<bool> confirmBookmarkDeletion(
  BuildContext context,
  Bookmark bookmark,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.bookmarksDeleteConfirm(bookmark.displayName)),
        content: Text(context.l10n.bookmarksDeleteConfirmDescription),
        actions: [
          TextButton(
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

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../constants/builtin_bookmarks.dart';
import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/context_menu/m3e_context_menu.dart';
import '../../../widgets/metadata_chip/metadata_chip.dart';
import '../../../widgets/overflow_text/overflow_text.dart';

/// One bookmark as a list segment: identity, address, protocols and tags, an
/// add-to-network button and the share/edit/delete menu.
///
/// A built-in shared node is read-only: its edit and delete actions are
/// disabled, and tapping it does nothing (it is never a section's `onTap`).
class BookmarkRow extends StatelessWidget {
  const BookmarkRow({
    super.key,
    required this.bookmark,
    required this.onAddToNetwork,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final VoidCallback onAddToNetwork;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final builtin = isBuiltinBookmark(bookmark);
    final category = bookmarkCategoryLabel(bookmark);

    return M3EContextMenu(
      tooltip: l10n.cardMoreOptions(bookmark.displayName),
      actions: [
        M3EMenuAction(
          icon: Icons.share_outlined,
          label: l10n.bookmarksShare,
          onPressed: onShare,
        ),
        M3EMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.bookmarksEdit,
          onPressed: builtin ? null : onEdit,
        ),
        M3EMenuAction(
          icon: Icons.delete_outline,
          label: l10n.bookmarksDelete,
          onPressed: builtin ? null : onDelete,
          destructive: true,
        ),
      ],
      builder: (context, menuButton) => M3EListItem(
        leading: M3EContainer(
          builtin ? Shapes.c9SidedCookie : Shapes.c4SidedCookie,
          width: 40,
          height: 40,
          color: builtin ? colors.tertiaryContainer : colors.primaryContainer,
          child: Icon(
            builtin ? Icons.public : Icons.bookmark,
            size: 20,
            color: builtin
                ? colors.onTertiaryContainer
                : colors.onPrimaryContainer,
          ),
        ),
        overline: category == null ? null : Text(category),
        headline: OverflowText(bookmark.displayName),
        supportingText: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(bookmark.address),
            for (final protocol in bookmark.node.protocols)
              MetadataChip.protocol(protocol.name),
            for (final tag in bookmark.tags) MetadataChip('#$tag'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: l10n.bookmarksAddToNetwork,
              onPressed: onAddToNetwork,
            ),
            menuButton,
          ],
        ),
      ),
    );
  }
}

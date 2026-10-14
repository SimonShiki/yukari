import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../constants/builtin_bookmarks.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/context_menu/m3e_context_menu.dart';

/// One bookmark row: its name, address, category and tags, with the actions
/// that can be taken on it.
class BookmarkListItem extends StatelessWidget {
  const BookmarkListItem({
    super.key,
    required this.bookmark,
    required this.onAddToNetwork,
    required this.onShare,
    this.onEdit,
    this.onDelete,
  });

  final Bookmark bookmark;
  final VoidCallback onAddToNetwork;
  final VoidCallback onShare;

  /// Null for built-in shared nodes, which the user cannot change.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final builtin = isBuiltinBookmark(bookmark);
    final category = bookmark.category?.trim();

    return M3EContextMenu(
      tooltip: context.l10n.cardMoreOptions(bookmark.displayName),
      actions: [
        M3EMenuAction(
          icon: Icons.share_outlined,
          label: context.l10n.bookmarksShare,
          onPressed: onShare,
        ),
        M3EMenuAction(
          icon: Icons.edit_outlined,
          label: context.l10n.bookmarksEdit,
          onPressed: onEdit,
        ),
        M3EMenuAction(
          icon: Icons.delete_outline,
          label: context.l10n.bookmarksDelete,
          onPressed: onDelete,
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
        overline: category == null || category.isEmpty
            ? null
            : Text(category, style: theme.textTheme.labelSmall),
        headline: Text(
          bookmark.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        supportingText: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              bookmark.address,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            for (final protocol in bookmark.node.protocols)
              Badge(
                backgroundColor: colors.secondaryContainer,
                textColor: colors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                label: Text(
                  protocol.name.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            for (final tag in bookmark.tags)
              Badge(
                backgroundColor: colors.surfaceContainerHighest,
                textColor: colors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                label: Text('#$tag', style: theme.textTheme.labelSmall),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: context.l10n.bookmarksAddToNetwork,
              onPressed: onAddToNetwork,
            ),
            menuButton,
          ],
        ),
      ),
    );
  }
}

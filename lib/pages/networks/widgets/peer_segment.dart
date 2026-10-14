import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/node.dart';
import 'list_editor_segments.dart';

/// One initial peer in the network editor: its address and protocols, a
/// button that saves it as a bookmark, and delete.
///
/// Tapping the row itself is handled by the section around it.
class PeerSegment extends StatelessWidget {
  const PeerSegment({
    super.key,
    required this.node,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.onDelete,
  });

  final Node node;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListEntrySegment(
      icon: Icons.person,
      shape: Shapes.c9SidedCookie,
      color: colors.primaryContainer,
      onColor: colors.onPrimaryContainer,
      headline: node.id,
      supporting: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${nodeHost(node.url)}:${node.port}'),
          for (final protocol in node.protocols)
            Badge(
              backgroundColor: colors.secondaryContainer,
              textColor: colors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              label: Text(
                protocol.name.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
      deleteTooltip: context.l10n.networkDeletePeer,
      onDelete: onDelete,
      actions: [
        IconButton(
          icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined),
          tooltip: bookmarked
              ? context.l10n.peersRemoveBookmark
              : context.l10n.peersSaveToBookmarks,
          onPressed: onToggleBookmark,
        ),
      ],
    );
  }
}

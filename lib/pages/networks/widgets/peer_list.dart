import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../widgets/bookmark_picker/bookmark_picker_dialog.dart';
import '../../../widgets/list_editor/list_editor_segments.dart';
import '../../../widgets/metadata_chip/metadata_chip.dart';

/// Offers the bookmarks that are not peers yet; [sharedOnly] leaves the user's
/// own bookmarks out.
Future<void> pickPeerBookmarks(
  BuildContext context,
  NetworkEditorController controller, {
  required bool sharedOnly,
}) async {
  final present = {for (final node in controller.nodes.value) nodeKey(node)};
  final source = sharedOnly
      ? controller.sharedBookmarks
      : controller.pickableBookmarks;
  final picked = await showBookmarkPicker(
    context,
    bookmarks: [
      for (final bookmark in source)
        if (!present.contains(nodeKey(bookmark.node))) bookmark,
    ],
  );
  if (picked == null || picked.isEmpty) return;
  controller.addBookmarks(picked);
}

/// One peer: its id, its endpoints and protocols, and its bookmark toggle.
class PeerRow extends StatelessWidget {
  const PeerRow({super.key, required this.controller, required this.node});

  final NetworkEditorController controller;
  final Node node;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListEntrySegment(
      icon: Icons.person,
      shape: Shapes.c9SidedCookie,
      color: colors.secondaryContainer,
      onColor: colors.onSecondaryContainer,
      headline: node.id,
      // The headline is already the id, so the row only adds the protocols.
      supporting: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final protocol in node.protocols)
            MetadataChip.protocol(protocol.name),
        ],
      ),
      deleteTooltip: l10n.networkDeletePeer,
      onDelete: () => controller.removePeer(node.id),
      actions: [
        SignalBuilder(
          builder: (context) {
            final saved = controller.bookmarkedNode(node).value;
            return IconButton(
              tooltip: saved
                  ? l10n.peersRemoveBookmark
                  : l10n.peersSaveToBookmarks,
              onPressed: () => controller.toggleBookmark(node),
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined),
            );
          },
        ),
      ],
    );
  }
}

/// What to do about an empty peer list: browse the bookmarks, or take a
/// bundled shared node.
class MissingPeersNotice extends StatelessWidget {
  const MissingPeersNotice({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shared = controller.sharedBookmarks;
    return Material(
      color: theme.colorScheme.tertiaryContainer,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              l10n.peersEmptyWarning,
              style: theme.emphasizedTextTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            if (shared.isEmpty)
              Text(
                l10n.peersEmptyNoPublic,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            Row(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => pickPeerBookmarks(
                    context,
                    controller,
                    sharedOnly: false,
                  ),
                  child: Text(l10n.peersEmptyBrowse),
                ),
                if (shared.isNotEmpty)
                  TextButton(
                    onPressed: () => pickPeerBookmarks(
                      context,
                      controller,
                      sharedOnly: true,
                    ),
                    child: Text(l10n.peersEmptyAddPublic),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

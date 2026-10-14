import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/builtin_bookmarks.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../models/node.dart';
import '../../../signals/bookmarks.dart';
import '../../../widgets/bookmark_picker/bookmark_picker_dialog.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/snackbar/app_snackbar.dart';
import 'empty_peers_notice.dart';
import 'list_editor_segments.dart';
import 'node_editor_dialog.dart';
import 'peer_segment.dart';

/// The "Initial Peers" section. Tapping a peer edits it; its bookmark button
/// saves the peer for reuse, and the footer adds saved bookmarks to this
/// network.
class NodeListEditor extends StatefulWidget {
  const NodeListEditor({
    super.key,
    required this.nodes,
    required this.onNodesChanged,
  });

  final List<Node> nodes;
  final ValueChanged<List<Node>> onNodesChanged;

  @override
  State<NodeListEditor> createState() => _NodeListEditorState();
}

class _NodeListEditorState extends State<NodeListEditor> {
  List<Node> get nodes => widget.nodes;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      // Reading the signal here keeps every row's bookmark button in step
      // with the store.
      final saved = bookmarks.value;

      return FormSection(
        title: context.l10n.networkInitialPeers,
        icon: Icons.people,
        description: context.l10n.networkInitialPeersDescription,
        banner: nodes.isEmpty
            ? EmptyPeersNotice(
                hasPublicNodes: builtinBookmarks.isNotEmpty,
                onAddPublic: () => _addFromBookmarks(sharedOnly: true),
                onBrowse: () => _addFromBookmarks(sharedOnly: false),
              )
            : null,
        footer: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            M3EButton.icon(
              style: M3EButtonStyle.tonal,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.networkAddPeer),
              onPressed: () => _showNodeDialog(null),
            ),
            M3EButton.icon(
              style: M3EButtonStyle.tonal,
              icon: const Icon(Icons.bookmarks_outlined),
              label: Text(context.l10n.bookmarksFromBookmarks),
              onPressed: () => _addFromBookmarks(sharedOnly: false),
            ),
          ],
        ),
        onTap: nodes.isEmpty ? null : (i) => _showNodeDialog(nodes[i]),
        semanticLabelBuilder: nodes.isEmpty
            ? null
            : (i) => context.l10n.networkEditPeerNamed(nodes[i].id),
        children: nodes.isEmpty
            ? [
                EmptyListSegment(
                  icon: Icons.person_add,
                  text: context.l10n.networkNoConfiguredPeers,
                ),
              ]
            : [
                for (final (index, node) in nodes.indexed)
                  PeerSegment(
                    node: node,
                    bookmarked: saved.any(
                      (bookmark) => sameNode(bookmark.node, node),
                    ),
                    onToggleBookmark: () => _toggleBookmark(node),
                    onDelete: () => _deleteNode(index),
                  ),
              ],
      );
    },
  );

  void _showNodeDialog(Node? existingNode) {
    showDialog<void>(
      context: context,
      builder: (context) => NodeEditorDialog(
        initialNode: existingNode,
        existingIds: nodes.map((n) => n.id).toList(),
        onSave: (node) {
          final newList = List<Node>.from(nodes);
          if (existingNode != null) {
            final index = newList.indexWhere((n) => n.id == existingNode.id);
            if (index != -1) {
              newList[index] = node;
            }
          } else {
            newList.add(node);
          }
          widget.onNodesChanged(newList);
        },
      ),
    );
  }

  void _deleteNode(int index) {
    final newList = List<Node>.from(nodes)..removeAt(index);
    widget.onNodesChanged(newList);
  }

  /// Adds the bookmarks the user picks — or only the shared ones — to the
  /// network's initial peers.
  Future<void> _addFromBookmarks({required bool sharedOnly}) async {
    final available = [
      for (final bookmark in [...builtinBookmarks, ...bookmarks.value])
        if ((!sharedOnly || isBuiltinBookmark(bookmark)) &&
            !nodes.any((node) => sameNode(node, bookmark.node)))
          bookmark,
    ];
    final chosen = await showBookmarkPicker(context, bookmarks: available);
    if (chosen == null || chosen.isEmpty || !mounted) return;
    widget.onNodesChanged([
      ...nodes,
      for (final bookmark in chosen) bookmark.node.copy(),
    ]);
  }

  /// Saves [node] as a bookmark, or removes the bookmark already holding it.
  Future<void> _toggleBookmark(Node node) async {
    final l10n = context.l10n;
    final existing = bookmarkFor(node);
    try {
      if (existing != null) {
        await deleteBookmark(existing.id);
        if (!mounted) return;
        showAppSnackBar(context, l10n.bookmarksRemoved);
        return;
      }
      await addBookmark(
        Bookmark(id: const Uuid().v4(), node: node.copy(), name: node.id),
      );
      if (!mounted) return;
      showAppSnackBar(context, l10n.bookmarksSaved);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, l10n.bookmarksSaveFailed('$error'));
    }
  }
}

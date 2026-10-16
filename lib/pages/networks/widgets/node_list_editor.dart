import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yukari/controllers/network_editor_controller.dart';

import '../../../constants/builtin_bookmarks.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../models/node.dart';
import '../../../signals/bookmarks.dart';
import '../../../signals/networks.dart';
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
  const NodeListEditor({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  State<NodeListEditor> createState() => _NodeListEditorState();
}

class _NodeListEditorState extends State<NodeListEditor> {
  NetworkEditorController get _editor => widget.controller;
  late final nodes = computed(() => _editor.editing.value.nodes);

  @override
  void dispose() {
    nodes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final list = nodes.value;
      // Reading the signal here keeps every row's bookmark button in step
      // with the store.
      final saved = bookmarks.value;

      return FormSection(
        title: context.l10n.networkInitialPeers,
        icon: Icons.people,
        description: context.l10n.networkInitialPeersDescription,
        banner: list.isEmpty
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
        onTap: list.isEmpty ? null : (i) => _showNodeDialog(list[i]),
        semanticLabelBuilder: list.isEmpty
            ? null
            : (i) => context.l10n.networkEditPeerNamed(list[i].id),
        children: list.isEmpty
            ? [
                EmptyListSegment(
                  icon: Icons.person_add,
                  text: context.l10n.networkNoConfiguredPeers,
                ),
              ]
            : [
                for (final (index, node) in list.indexed)
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

  /// Replaces this network's peers, saving through the networks store.
  void _setNodes(List<Node> list) =>
      updateNetwork(_editor.name, updater: (network) => network.nodes = list);

  void _showNodeDialog(Node? existingNode) {
    final current = nodes.value;
    showDialog<void>(
      context: context,
      builder: (context) => NodeEditorDialog(
        initialNode: existingNode,
        existingIds: current.map((n) => n.id).toList(),
        onSave: (node) {
          final newList = List<Node>.from(current);
          if (existingNode != null) {
            final index = newList.indexWhere((n) => n.id == existingNode.id);
            if (index != -1) {
              newList[index] = node;
            }
          } else {
            newList.add(node);
          }
          _setNodes(newList);
        },
      ),
    );
  }

  void _deleteNode(int index) {
    final newList = List<Node>.from(nodes.value)..removeAt(index);
    _setNodes(newList);
  }

  /// Adds the bookmarks the user picks — or only the shared ones — to the
  /// network's initial peers.
  Future<void> _addFromBookmarks({required bool sharedOnly}) async {
    final current = nodes.value;
    final available = [
      for (final bookmark in [...builtinBookmarks, ...bookmarks.value])
        if ((!sharedOnly || isBuiltinBookmark(bookmark)) &&
            !current.any((node) => sameNode(node, bookmark.node)))
          bookmark,
    ];
    final chosen = await showBookmarkPicker(context, bookmarks: available);
    if (chosen == null || chosen.isEmpty || !mounted) return;
    _setNodes([
      ...current,
      for (final bookmark in chosen) bookmark.node.copy(),
    ]);
  }

  /// Saves [node] as a bookmark, or removes the bookmark already holding it.
  void _toggleBookmark(Node node) {
    final l10n = context.l10n;
    final existing = bookmarkFor(node);
    try {
      if (existing != null) {
        deleteBookmark(existing.id);
        showAppSnackBar(context, l10n.bookmarksRemoved);
        return;
      }
      addBookmark(
        Bookmark(id: const Uuid().v4(), node: node.copy(), name: node.id),
      );
      showAppSnackBar(context, l10n.bookmarksSaved);
    } catch (error) {
      showAppSnackBar(context, l10n.bookmarksSaveFailed('$error'));
    }
  }
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/list_editor/list_editor_segments.dart';
import 'node_dialog.dart';
import 'peer_list.dart';

/// The nodes the network connects to when it starts.
class EditorPeersSection extends StatelessWidget {
  const EditorPeersSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final nodes = controller.nodes.value;
      return FormSection(
        title: l10n.networkInitialPeers,
        icon: Icons.people,
        description: l10n.networkInitialPeersDescription,
        banner: nodes.isEmpty
            ? MissingPeersNotice(controller: controller)
            : null,
        footer: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            M3EButton.icon(
              onPressed: () => _addPeer(context),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: Text(l10n.networkAddPeer),
              style: M3EButtonStyle.tonal,
            ),
            M3EButton.icon(
              onPressed: () => pickPeerBookmarks(
                context,
                controller,
                sharedOnly: false,
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l10n.bookmarksFromBookmarks),
              style: M3EButtonStyle.tonal,
            ),
          ],
        ),
        onTap: nodes.isEmpty
            ? null
            : (index) => _editPeer(context, nodes[index]),
        semanticLabelBuilder: nodes.isEmpty
            ? null
            : (index) => l10n.networkEditPeerNamed(nodes[index].id),
        children: [
          if (nodes.isEmpty)
            EmptyListSegment(
              icon: Icons.person_add,
              text: l10n.networkNoConfiguredPeers,
            )
          else
            for (final node in nodes)
              PeerRow(controller: controller, node: node),
        ],
      );
    },
  );

  List<String> get _ids => [for (final node in controller.nodes.value) node.id];

  Future<void> _addPeer(BuildContext context) async {
    final peer = await showNodeDialog(context, existingIds: _ids);
    if (peer != null) controller.addPeer(peer);
  }

  Future<void> _editPeer(BuildContext context, Node node) async {
    final peer = await showNodeDialog(context, node: node, existingIds: _ids);
    if (peer != null) controller.addPeer(peer);
  }
}

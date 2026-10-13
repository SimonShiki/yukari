import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/node.dart';
import 'list_editor_segments.dart';
import '../../../widgets/form_section/form_section.dart';
import 'node_editor_dialog.dart';

/// The "Initial Peers" section. Tapping a peer edits it.
class NodeListEditor extends StatelessWidget {
  const NodeListEditor({
    super.key,
    required this.nodes,
    required this.onNodesChanged,
  });

  final List<Node> nodes;
  final ValueChanged<List<Node>> onNodesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return FormSection(
      title: 'Initial Peers',
      icon: Icons.people,
      description: 'Configure nodes to connect when starting the network',
      footer: M3EButton.icon(
        style: M3EButtonStyle.tonal,
        icon: const Icon(Icons.add),
        label: const Text('Add Peer'),
        onPressed: () => _showNodeDialog(context, null),
      ),
      onTap: nodes.isEmpty ? null : (i) => _showNodeDialog(context, nodes[i]),
      semanticLabelBuilder: nodes.isEmpty
          ? null
          : (i) => 'Edit peer ${nodes[i].id}',
      children: nodes.isEmpty
          ? const [
              EmptyListSegment(
                icon: Icons.person_add,
                text: 'No peers configured',
              ),
            ]
          : [
              for (final (index, node) in nodes.indexed)
                ListEntrySegment(
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
                      Text('${node.url.host}:${node.port}'),
                      for (final p in node.protocols)
                        Badge(
                          backgroundColor: colors.secondaryContainer,
                          textColor: colors.onSecondaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          label: Text(
                            p.name.toUpperCase(),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  deleteTooltip: 'Delete peer',
                  onDelete: () => _deleteNode(index),
                ),
            ],
    );
  }

  void _showNodeDialog(BuildContext context, Node? existingNode) {
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
          onNodesChanged(newList);
        },
      ),
    );
  }

  void _deleteNode(int index) {
    final newList = List<Node>.from(nodes)..removeAt(index);
    onNodesChanged(newList);
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../models/node.dart';
import 'node_editor_dialog.dart';

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
    if (nodes.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...nodes.asMap().entries.map((entry) {
          final index = entry.key;
          final node = entry.value;
          return _buildNodeCard(context, node, index);
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Peer'),
          onPressed: () => _showNodeDialog(context, null),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.person_add,
          size: 48,
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'No peers configured',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Peer'),
          onPressed: () => _showNodeDialog(context, null),
        ),
      ],
    );
  }

  Widget _buildNodeCard(BuildContext context, Node node, int index) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.outlineVariant,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.person),
        ),
        title: Text(node.id),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${node.url.host}:${node.port}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: node.protocols.map((p) => Chip(
                label: Text(
                  p.name.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showNodeDialog(context, node),
              tooltip: 'Edit peer',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteNode(index),
              tooltip: 'Delete peer',
            ),
          ],
        ),
        isThreeLine: true,
      ),
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

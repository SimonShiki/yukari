import 'package:material_ui/material_ui.dart';

import 'listener_editor_dialog.dart';

class ListenerListEditor extends StatelessWidget {
  const ListenerListEditor({
    super.key,
    required this.listeners,
    required this.onListenersChanged,
    this.title = 'Listeners',
  });

  final List<Uri> listeners;
  final ValueChanged<List<Uri>> onListenersChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (listeners.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...listeners.asMap().entries.map((entry) {
          final index = entry.key;
          final listener = entry.value;
          return _buildListenerCard(context, listener, index);
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text('Add $title'),
          onPressed: () => _showListenerDialog(context, null),
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
          Icons.podcasts,
          size: 48,
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'No $title configured',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text('Add $title'),
          onPressed: () => _showListenerDialog(context, null),
        ),
      ],
    );
  }

  Widget _buildListenerCard(BuildContext context, Uri listener, int index) {
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
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: const Icon(Icons.podcasts),
        ),
        title: Text(listener.toString()),
        subtitle: Text('${listener.scheme.toUpperCase()} • ${listener.host}:${listener.port}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showListenerDialog(context, listener),
              tooltip: 'Edit listener',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteListener(index),
              tooltip: 'Delete listener',
            ),
          ],
        ),
      ),
    );
  }

  void _showListenerDialog(BuildContext context, Uri? existingListener) {
    showDialog<void>(
      context: context,
      builder: (context) => ListenerEditorDialog(
        initialListener: existingListener,
        onSave: (listener) {
          final newList = List<Uri>.from(listeners);
          if (existingListener != null) {
            final index = newList.indexOf(existingListener);
            if (index != -1) {
              newList[index] = listener;
            }
          } else {
            newList.add(listener);
          }
          onListenersChanged(newList);
        },
      ),
    );
  }

  void _deleteListener(int index) {
    final newList = List<Uri>.from(listeners)..removeAt(index);
    onListenersChanged(newList);
  }
}

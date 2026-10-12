import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'list_editor_segments.dart';
import 'listener_editor_dialog.dart';
import 'network_form_section.dart';

/// The listeners section. Tapping a listener edits it.
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
    final colors = Theme.of(context).colorScheme;

    return NetworkFormSection(
      title: title,
      icon: Icons.podcasts,
      description: 'Local addresses for incoming connections',
      footer: M3EButton.icon(
        style: M3EButtonStyle.tonal,
        icon: const Icon(Icons.add),
        label: Text('Add $title'),
        onPressed: () => _showListenerDialog(context, null),
      ),
      onTap: listeners.isEmpty
          ? null
          : (i) => _showListenerDialog(context, listeners[i]),
      semanticLabelBuilder: listeners.isEmpty
          ? null
          : (i) => 'Edit listener ${listeners[i]}',
      children: listeners.isEmpty
          ? [
              EmptyListSegment(
                icon: Icons.podcasts,
                text: 'No $title configured',
              ),
            ]
          : [
              for (final (index, listener) in listeners.indexed)
                ListEntrySegment(
                  icon: Icons.podcasts,
                  shape: Shapes.c4SidedCookie,
                  color: colors.secondaryContainer,
                  onColor: colors.onSecondaryContainer,
                  headline: listener.toString(),
                  supporting: Text(
                    '${listener.scheme.toUpperCase()} • '
                    '${listener.host}:${listener.port}',
                  ),
                  deleteTooltip: 'Delete listener',
                  onDelete: () => _deleteListener(index),
                ),
            ],
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

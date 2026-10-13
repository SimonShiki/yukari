import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'list_editor_segments.dart';
import 'listener_editor_dialog.dart';
import '../../../widgets/form_section/form_section.dart';

/// The listeners section. Tapping a listener edits it.
class ListenerListEditor extends StatelessWidget {
  const ListenerListEditor({
    super.key,
    required this.listeners,
    required this.onListenersChanged,
    this.title,
    this.description,
    this.collapsible = false,
  });

  final List<Uri> listeners;
  final ValueChanged<List<Uri>> onListenersChanged;
  final String? title;
  final String? description;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sectionTitle = title ?? context.l10n.networkListeners;

    return FormSection(
      title: sectionTitle,
      icon: Icons.podcasts,
      description: description ?? context.l10n.networkListenersDescription,
      collapsible: collapsible,
      footer: M3EButton.icon(
        style: M3EButtonStyle.tonal,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.networkAddListeners(sectionTitle)),
        onPressed: () => _showListenerDialog(context, null),
      ),
      onTap: listeners.isEmpty
          ? null
          : (i) => _showListenerDialog(context, listeners[i]),
      semanticLabelBuilder: listeners.isEmpty
          ? null
          : (i) =>
                context.l10n.networkEditListenerNamed(listeners[i].toString()),
      children: listeners.isEmpty
          ? [
              EmptyListSegment(
                icon: Icons.podcasts,
                text: context.l10n.networkNoListeners(sectionTitle),
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
                  deleteTooltip: context.l10n.networkDeleteListener,
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

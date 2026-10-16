import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/list_editor/list_editor_segments.dart';
import 'listener_dialog.dart';

/// A listener list editor, shared by the listeners and the mapped listeners.
class EditorListenerSection extends StatelessWidget {
  const EditorListenerSection({
    super.key,
    required this.controller,
    required this.list,
    required this.title,
    required this.description,
    this.collapsible = true,
  });

  final NetworkEditorController controller;

  /// Which of the network's two listener lists this section edits.
  final ListenerList list;
  final String title;
  final String description;

  /// The listeners section is always open; the mapped listeners collapse.
  final bool collapsible;

  Signal<List<Uri>> get _shown => list == ListenerList.local
      ? controller.listeners
      : controller.mappedListeners;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final listeners = _shown.value;
      return FormSection(
        title: title,
        icon: Icons.podcasts,
        description: description,
        collapsible: collapsible,
        footer: M3EButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.networkAddListeners(title)),
          style: M3EButtonStyle.tonal,
        ),
        onTap: listeners.isEmpty
            ? null
            : (index) => _edit(context, listeners, index),
        semanticLabelBuilder: listeners.isEmpty
            ? null
            : (index) =>
                  l10n.networkEditListenerNamed(listeners[index].toString()),
        children: [
          if (listeners.isEmpty)
            EmptyListSegment(
              icon: Icons.podcasts,
              text: l10n.networkNoListeners(title),
            )
          else
            for (final listener in listeners) _row(context, listener),
        ],
      );
    },
  );

  Widget _row(BuildContext context, Uri listener) {
    final colors = Theme.of(context).colorScheme;
    return ListEntrySegment(
      icon: Icons.podcasts,
      shape: Shapes.c9SidedCookie,
      color: colors.secondaryContainer,
      onColor: colors.onSecondaryContainer,
      headline: listener.toString(),
      supporting: Text(
        '${listener.scheme.toUpperCase()} • ${listener.host}:${listener.port}',
      ),
      deleteTooltip: context.l10n.networkDeleteListener,
      onDelete: () => controller.removeListener(list, listener),
    );
  }

  Future<void> _add(BuildContext context) async {
    final picked = await showListenerDialog(context);
    if (picked != null) controller.setListener(list, picked);
  }

  Future<void> _edit(BuildContext context, List<Uri> listeners, int index) async {
    final previous = listeners[index];
    final picked = await showListenerDialog(context, listener: previous);
    if (picked != null) {
      controller.setListener(list, picked, previous: previous);
    }
  }
}

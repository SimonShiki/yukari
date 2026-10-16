import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/models.dart';
import '../../../widgets/form_section/form_segments.dart';

/// A switch segment bound to one boolean of the working copy, so flipping it
/// rebuilds that segment only.
class EditorSwitch extends StatelessWidget {
  const EditorSwitch({
    super.key,
    required this.controller,
    required this.name,
    required this.read,
    required this.write,
    required this.title,
    required this.subtitle,
  });

  final NetworkEditorController controller;

  /// Unique key of this switch's primitive.
  final String name;
  final bool Function(Network network) read;
  final void Function(Network network, bool value) write;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final value = controller.select('switch.$name', read, false).value;
      return SwitchSegment(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: (bool value) =>
            controller.update((network) => write(network, value)),
      );
    },
  );
}

/// A single-select dropdown segment that saves the chosen option.
class EditorDropdown<T> extends StatelessWidget {
  const EditorDropdown({
    super.key,
    required this.label,
    this.helper,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final String? helper;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => FieldSegment(
    child: DropdownMenu<T>(
      // A new selection from outside rebuilds the menu with it.
      key: ValueKey(value),
      initialSelection: value,
      label: Text(label),
      helperText: helper,
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: [
        for (final option in options)
          DropdownMenuEntry<T>(value: option, label: labelOf(option)),
      ],
      onSelected: (option) {
        if (option != null) onSelected(option);
      },
    ),
  );
}

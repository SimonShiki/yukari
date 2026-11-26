import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari_core/models/models.dart';

import '../../../controllers/networks/network_editor_controller.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/select_item/select_item.dart';

/// A switch segment bound to one boolean of the working copy, so flipping it
/// rebuilds that segment only.
class EditorSwitch extends StatelessWidget {
  const EditorSwitch({
    super.key,
    required this.icon,
    required this.controller,
    required this.name,
    required this.read,
    required this.write,
    required this.title,
    required this.subtitle,
    this.conflict,
  });

  /// The leading icon naming the setting.
  final IconData icon;
  final NetworkEditorController controller;

  /// Unique key of this switch's primitive.
  final String name;
  final bool Function(Network network) read;
  final void Function(Network network, bool value) write;
  final String title;
  final String subtitle;

  /// The conflicting switch and the explanation shown while it blocks this one.
  final ({String name, bool Function(Network) read, String subtitle})? conflict;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final value = editorSwitch(controller, name, read).value;
      final conflict = this.conflict;
      // A saved pair with both switches on can be repaired from either side.
      final enabled =
          conflict == null ||
          value ||
          !editorSwitch(controller, conflict.name, conflict.read).value;
      return SwitchSegment(
        icon: icon,
        title: title,
        subtitle: enabled ? subtitle : conflict.subtitle,
        value: value,
        enabled: enabled,
        onChanged: (bool value) =>
            controller.update((network) => write(network, value)),
      );
    },
  );
}

/// The primitive one editor switch binds, so the switch that conflicts with it
/// subscribes to the very same signal.
ReadonlySignal<bool> editorSwitch(
  NetworkEditorController controller,
  String name,
  bool Function(Network) read,
) => controller.select('switch.$name', read, false);

/// A select row bound to a typed field of the working copy.
class EditorSelect<T> extends StatelessWidget {
  const EditorSelect({
    super.key,
    required this.icon,
    required this.label,
    required this.supportingText,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String supportingText;
  final ReadonlySignal<T> value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => SelectItem<T>(
      icon: icon,
      label: label,
      supportingText: supportingText,
      value: value.value,
      options: options,
      labelOf: labelOf,
      onSelected: onSelected,
    ),
  );
}

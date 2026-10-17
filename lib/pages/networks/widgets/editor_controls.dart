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
    required this.icon,
    required this.controller,
    required this.name,
    required this.read,
    required this.write,
    required this.title,
    required this.subtitle,
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

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final value = controller.select('switch.$name', read, false).value;
      return SwitchSegment(
        icon: icon,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: (bool value) =>
            controller.update((network) => write(network, value)),
      );
    },
  );
}

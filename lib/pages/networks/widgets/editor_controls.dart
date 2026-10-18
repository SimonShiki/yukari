import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import 'package:yukari_core/models/models.dart';
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
    this.enabled = true,
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

  /// Whether the setting can still move.
  final bool enabled;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final value = editorSwitch(controller, name, read).value;
      return SwitchSegment(
        icon: icon,
        title: title,
        subtitle: subtitle,
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

/// Rule between two conflicting switches: turning [value] off is always
/// allowed, turning it on waits for [conflicts] to be off. A saved network
/// that has both on therefore stays repairable from either side.
bool editorSwitchEnabled({required bool value, required bool conflicts}) =>
    !conflicts || value;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/connected_gap.dart';

/// One of a share page's either-or settings: the choices, side by side, each
/// as wide as the others and as wide as [labels] needs them to be.
///
/// The group fills the width it is given, which is the card's, so it needs no
/// window-size branch: a share page caps its column well below the widest
/// window. [selectedIndex] is a plain value, so the caller reads the signal in
/// its own build and this widget stays free of the controller.
class ShareChoiceGroup extends StatelessWidget {
  const ShareChoiceGroup({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.semanticLabel,
  });

  /// The choice labels, in the order the setting's values are indexed.
  final List<String> labels;

  /// Which choice is current.
  final int selectedIndex;

  /// Called with the index of the choice the user picked.
  final ValueChanged<int> onSelected;

  /// What the group chooses, for a screen reader.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final segment =
          (constraints.maxWidth - (labels.length - 1) * connectedGap) /
          labels.length;
      return M3EToggleButtonGroup(
        type: M3EButtonGroupType.connected,
        size: M3EButtonSize.sm,
        semanticLabel: semanticLabel,
        selectedIndex: selectedIndex,
        onSelectedIndexChanged: (index) {
          if (index != null) onSelected(index);
        },
        actions: [
          for (final label in labels)
            M3EToggleButtonGroupAction(label: Text(label), width: segment),
        ],
      );
    },
  );
}

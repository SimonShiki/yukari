import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'network_card.dart';
import 'network_card_data.dart';
import 'network_card_geometry.dart';
import 'network_card_menu.dart';

class NetworkCardList extends StatelessWidget {
  const NetworkCardList({
    super.key,
    required this.networks,
    required this.onReorder,
    required this.keyBuilder,
    this.selecting = false,
    this.selectedIndices = const <int>{},
    this.onSelectionChanged,
  });

  final List<NetworkCardData> networks;
  final ReorderCallback onReorder;
  final Key Function(int index) keyBuilder;

  /// Whether the rows select like a gallery, many at a time, instead of acting
  /// as the page's current one.
  final bool selecting;

  /// The rows selected: the page's current row, or the gallery's selection.
  final Set<int> selectedIndices;

  /// Called with the rows selected after a tap.
  final ValueChanged<Set<int>>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return M3EReorderableSegmentedList.builder(
      itemCount: networks.length,
      keyBuilder: keyBuilder,
      onReorder: onReorder,
      buildDefaultDragHandles: false,
      listPadding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      selectionMode: selecting
          ? M3ESelectionMode.multiple
          : M3ESelectionMode.single,
      selectionTrigger: M3ESelectionTrigger.tap,
      selectedIndices: selectedIndices,
      onSelectionChanged: onSelectionChanged,
      selectedColor: colors.secondaryContainer,
      showSelectionCheckmark: false,
      itemBuilder: (context, index) {
        final network = networks[index];
        Widget card(Widget menuButton) => NetworkCard(
          name: network.name,
          running: network.running,
          status: network.status,
          onToggle: network.onToggle,
          menuButton: menuButton,
          selecting: selecting,
          selected: selectedIndices.contains(index),
        );
        // A selecting row carries no menu: its gesture would compete with the
        // tap that toggles the row.
        if (selecting) {
          return NetworkCardGeometry(child: card(const SizedBox.shrink()));
        }
        return NetworkCardGeometry(
          child: NetworkCardMenu(
            name: network.name,
            running: network.running,
            busy: network.busy,
            onEdit: network.onEdit,
            onShare: network.onShare,
            onExport: network.onExport,
            onLog: network.onLog,
            onDelete: network.onDelete,
            builder: (context, menuButton) => card(menuButton),
          ),
        );
      },
    );
  }
}

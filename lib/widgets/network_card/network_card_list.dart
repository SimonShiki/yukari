import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'network_card.dart';
import 'network_card_data.dart';
import 'network_card_menu.dart';

class NetworkCardList extends StatelessWidget {
  const NetworkCardList({
    super.key,
    required this.networks,
    required this.onReorder,
    required this.keyBuilder,
    this.showDragHandles = false,
    this.selectedIndex,
    this.onSelectionChanged,
  });

  final List<NetworkCardData> networks;
  final ReorderCallback onReorder;
  final Key Function(int index) keyBuilder;
  final bool showDragHandles;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return M3EReorderableSegmentedList.builder(
      itemCount: networks.length,
      keyBuilder: keyBuilder,
      onReorder: onReorder,
      buildDefaultDragHandles: showDragHandles,
      listPadding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      selectionMode: M3ESelectionMode.single,
      selectionTrigger: M3ESelectionTrigger.tap,
      selectedIndices: selectedIndex != null ? {selectedIndex!} : {},
      onSelectionChanged: (indices) {
        onSelectionChanged?.call(indices.isEmpty ? null : indices.first);
      },
      selectedColor: colors.secondaryContainer,
      itemBuilder: (context, index) {
        final network = networks[index];
        return NetworkCardMenu(
          name: network.name,
          running: network.running,
          busy: network.busy,
          onEdit: network.onEdit,
          onLog: network.onLog,
          onDelete: network.onDelete,
          builder: (context, menuButton) => NetworkCard(
            name: network.name,
            running: network.running,
            status: network.status,
            onToggle: network.onToggle,
            menuButton: menuButton,
          ),
        );
      },
    );
  }
}

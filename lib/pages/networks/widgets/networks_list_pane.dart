import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_page_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/empty_state/empty_state.dart';
import '../../../widgets/network_card/network_card_data.dart';
import '../../../widgets/network_card/network_card_list.dart';
import '../network_create_menu.dart';

/// The reorder the list runs while selecting: it moves nothing.
///
/// The list's long-press drag lifts a row; only the data is held still.
void _keepOrder(int oldIndex, int newIndex) {}

/// The list half of the networks page: the error banner, the networks, and the
/// create menu.
class NetworksListPane extends StatelessWidget {
  const NetworksListPane({
    super.key,
    required this.controller,
    required this.wide,
    required this.selecting,
    required this.onSelect,
  });

  final NetworkPageController controller;
  final bool wide;

  /// Whether the page is in selection mode, so the rows and the create menu
  /// make room for it.
  final bool selecting;

  /// Handles a row being selected, which opens a route on narrow windows.
  final void Function(List<NetworkCardData> cards, int? index) onSelect;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        children: [
          SignalBuilder(
            builder: (context) => switch (controller.refreshError.value) {
              null => const SizedBox.shrink(),
              final error => MaterialBanner(
                leading: const Icon(Icons.cloud_off_outlined),
                content: Text(error),
                actions: [
                  SignalBuilder(
                    builder: (context) => TextButton(
                      onPressed: controller.refreshing.value
                          ? null
                          : controller.refresh,
                      child: Text(context.l10n.commonRetry),
                    ),
                  ),
                ],
              ),
            },
          ),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                final cards = controller.cards.value;
                if (cards.isEmpty) {
                  return EmptyState(
                    icon: Icons.hub_outlined,
                    title: context.l10n.networkEmpty,
                    message: context.l10n.networkEmptyDescription,
                  );
                }
                final selection = controller.selection;
                final selected = controller.selectedId.value;
                final index = cards.indexWhere((card) => card.id == selected);
                final selectedIds = selection.ids.value;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 500 : 1000),
                    child: NetworkCardList(
                      networks: cards,
                      onReorder: selecting ? _keepOrder : controller.reorder,
                      keyBuilder: (index) => ValueKey(cards[index].id),
                      selecting: selecting,
                      selectedIndices: selecting
                          ? {
                              for (final (index, card) in cards.indexed)
                                if (selectedIds.contains(card.id)) index,
                            }
                          // Narrow windows show no pane, so nothing looks
                          // selected.
                          : {if (wide && index >= 0) index},
                      onSelectionChanged: selecting
                          ? (indices) => selection.select([
                              for (final index in indices) cards[index].id,
                            ])
                          : (indices) => onSelect(
                              cards,
                              indices.isEmpty ? null : indices.first,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      if (wide && !selecting)
        Positioned(
          right: 16,
          bottom: 16,
          child: NetworkCreateMenu(controller: controller),
        ),
    ],
  );
}

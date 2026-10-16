import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_page_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/empty_state/empty_state.dart';
import '../../../widgets/network_card/network_card_data.dart';
import '../../../widgets/network_card/network_card_list.dart';
import '../network_create_menu.dart';

/// The list half of the networks page: the error banner, the networks, and the
/// create menu.
class NetworksListPane extends StatelessWidget {
  const NetworksListPane({
    super.key,
    required this.controller,
    required this.wide,
    required this.onSelect,
  });

  final NetworkPageController controller;
  final bool wide;

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
                final selected = controller.selectedId.value;
                final index = cards.indexWhere((card) => card.id == selected);
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 500 : 1000),
                    child: NetworkCardList(
                      networks: cards,
                      onReorder: controller.reorder,
                      keyBuilder: (index) => ValueKey(cards[index].id),
                      // Narrow windows show no pane, so nothing looks selected.
                      selectedIndex: wide && index >= 0 ? index : null,
                      onSelectionChanged: (index) => onSelect(cards, index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      if (wide)
        Positioned(
          right: 16,
          bottom: 16,
          child: NetworkCreateMenu(controller: controller),
        ),
    ],
  );
}

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_instance_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/empty_state/empty_state.dart';
import '../../../widgets/log_entry/log_entry_list.dart';

class InstanceLogsTab extends StatelessWidget {
  const InstanceLogsTab({super.key, required this.controller});

  final NetworkInstanceController controller;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: Column(
        children: [
          SignalBuilder(builder: (context) => _filters(context)),
          Expanded(child: SignalBuilder(builder: (context) => _list(context))),
        ],
      ),
    ),
  );

  Widget _filters(BuildContext context) {
    final selected = controller.filter.value;
    final counts = controller.counts.value;
    // Wraps rather than scrolls, so no filter is hidden on narrow screens.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in LogFilter.values)
            FilterChip(
              label: Text('${_label(context.l10n, filter)} ${counts[filter]}'),
              selected: filter == selected,
              onSelected: counts[filter] == 0 && filter != selected
                  ? null
                  : (_) => controller.filter.value = filter,
            ),
        ],
      ),
    );
  }

  static String _label(AppLocalizations l10n, LogFilter filter) =>
      switch (filter) {
        LogFilter.all => l10n.networkFilterAll,
        LogFilter.errors => l10n.networkFilterErrors,
        LogFilter.peers => l10n.networkPeers,
        LogFilter.connections => l10n.networkFilterConnections,
        LogFilter.listeners => l10n.networkListeners,
      };

  Widget _list(BuildContext context) {
    final logs = controller.visibleLogs.value;
    final expanded = controller.expanded.value;
    if (logs.isEmpty) {
      return EmptyState(
        icon: Icons.article_outlined,
        title: context.l10n.networkNoEvents,
        message: context.l10n.networkNoEventsDescription,
      );
    }
    return LogEntryList(
      // A new filter is a new list; start it from the newest entry.
      key: ValueKey(controller.filter.value),
      entries: logs,
      isExpanded: expanded.contains,
      onToggle: controller.toggleExpanded,
    );
  }
}

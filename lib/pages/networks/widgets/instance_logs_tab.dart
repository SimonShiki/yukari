import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_instance_controller.dart';
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
          SignalBuilder(builder: (context) => _filters()),
          Expanded(child: SignalBuilder(builder: (context) => _list())),
        ],
      ),
    ),
  );

  Widget _filters() {
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
              label: Text('${filter.label} ${counts[filter]}'),
              selected: filter == selected,
              onSelected: counts[filter] == 0 && filter != selected
                  ? null
                  : (_) => controller.filter.value = filter,
            ),
        ],
      ),
    );
  }

  Widget _list() {
    final logs = controller.visibleLogs.value;
    final expanded = controller.expanded.value;
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: 'No events yet',
        message: 'Network events appear here as they happen.',
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

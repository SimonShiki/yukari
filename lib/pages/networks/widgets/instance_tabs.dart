import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/networks/network_instance_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/empty_state/empty_state.dart';
import 'log_entry/log_entry_list.dart';
import 'peer_card/peer_card.dart';

/// The peers of one running network, this device first.
class InstancePeersTab extends StatelessWidget {
  const InstancePeersTab({super.key, required this.controller});

  final NetworkInstanceController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      if (!controller.loaded.value) {
        return const Center(child: M3ELoadingIndicator());
      }
      if (!controller.isRunning.value) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.networkNotRunning,
          message: l10n.networkNotRunningDescription,
        );
      }
      final peers = controller.peerCards.value;
      return CustomScrollView(
        slivers: [
          if (peers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.group_outlined,
                title: l10n.networkNoPeers,
                message: l10n.networkNoPeersDescription,
              ),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                // Keep the peers in an 840px max-width column on wide windows,
                // without losing laziness.
                final inset = math.max(
                  0.0,
                  (constraints.crossAxisExtent - 840) / 2,
                );
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(16 + inset, 12, 16 + inset, 16),
                  sliver: SliverM3ESegmentedList(
                    itemCount: peers.length,
                    itemBuilder: (context, index) =>
                        PeerCard(data: peers[index]),
                    padding: const EdgeInsets.all(12),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

/// The recorded events of one network, filtered by category.
class InstanceLogsTab extends StatelessWidget {
  const InstanceLogsTab({super.key, required this.controller});

  final NetworkInstanceController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in LogFilter.values) _filterChip(category),
            ],
          ),
        ),
      ),
      Expanded(
        child: SignalBuilder(
          builder: (context) {
            final entries = controller.visibleLogs.value;
            if (entries.isEmpty) {
              return EmptyState(
                icon: Icons.article_outlined,
                title: context.l10n.networkNoEvents,
                message: context.l10n.networkNoEventsDescription,
              );
            }
            final expanded = controller.expanded.value;
            return LogEntryList(
              key: ValueKey(controller.filter.value),
              entries: entries,
              isExpanded: (entry) => expanded.contains(entry.raw),
              onToggle: controller.toggleExpanded,
            );
          },
        ),
      ),
    ],
  );

  Widget _filterChip(LogFilter category) => SignalBuilder(
    builder: (context) {
      final count = controller.count(category).value;
      final selected = category == controller.filter.value;
      return FilterChip(
        label: Text('${_label(context, category)} $count'),
        selected: selected,
        onSelected: count == 0 && !selected
            ? null
            : (_) => controller.selectFilter(category),
      );
    },
  );

  static String _label(BuildContext context, LogFilter category) =>
      switch (category) {
        LogFilter.all => context.l10n.networkFilterAll,
        LogFilter.errors => context.l10n.networkFilterErrors,
        LogFilter.peers => context.l10n.networkPeers,
        LogFilter.connections => context.l10n.networkFilterConnections,
        LogFilter.listeners => context.l10n.networkListeners,
      };
}

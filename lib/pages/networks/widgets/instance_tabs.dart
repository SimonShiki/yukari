import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_instance_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/system/magic_dns.dart';
import '../../../widgets/empty_state/empty_state.dart';
import '../../../widgets/log_entry/log_entry_list.dart';
import '../../../widgets/peer_card/peer_card.dart';
import 'magic_dns_card.dart';

/// The peers of one running network, this device first, with the Magic DNS
/// helper above them while it needs attention.
class InstancePeersTab extends StatelessWidget {
  const InstancePeersTab({
    super.key,
    required this.controller,
    this.magicDnsSystem,
  });

  final NetworkInstanceController controller;

  /// Test-only: the system reader the Magic DNS card uses. Null reads the
  /// host; production never sets this.
  @visibleForTesting
  final MagicDnsSystem? magicDnsSystem;

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
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: MagicDnsCard(
                  networkId: controller.id,
                  system: magicDnsSystem,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                ),
              ),
            ),
          ),
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
                // Keep the peers in the same 840 wide column as the helper
                // above them on wide windows, without losing laziness.
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
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final filter = controller.filter.value;
      final entries = controller.visibleLogs.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in LogFilter.values)
                    _filterChip(context, category, filter),
                ],
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyState(
                    icon: Icons.article_outlined,
                    title: l10n.networkNoEvents,
                    message: l10n.networkNoEventsDescription,
                  )
                // Only the list follows the expanded entries, so opening one
                // does not rebuild the chips above it.
                : SignalBuilder(
                    builder: (context) {
                      // Subscribed here, so opening one entry rebuilds the
                      // list only, not the chips above it.
                      final expanded = controller.expanded.value;
                      return LogEntryList(
                        // Switching filters starts from the newest entry.
                        key: ValueKey(filter),
                        entries: entries,
                        isExpanded: (entry) => expanded.contains(entry.raw),
                        onToggle: controller.toggleExpanded,
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  Widget _filterChip(BuildContext context, LogFilter category, LogFilter selected) =>
      SignalBuilder(
        builder: (context) {
          final count = controller.count(category).value;
          return FilterChip(
            label: Text('${_label(context, category)} $count'),
            selected: category == selected,
            onSelected: count == 0 && category != selected
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

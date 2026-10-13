import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/byte_units.dart';
import 'dashboard_card.dart';

/// How fast the running networks exchange data with their peers, and how
/// much they did so far.
class TrafficCard extends StatelessWidget {
  const TrafficCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => DashboardCard(
      icon: Icons.swap_vert_rounded,
      shape: Shapes.l4LeafClover,
      title: context.l10n.homeTraffic,
      child: switch (controller.traffic.value) {
        _ when !controller.refreshed.value => const DashboardValue.loading(),
        null => DashboardValue(
          value: context.l10n.homeNoTraffic,
          supporting: context.l10n.homeNoRunningNetwork,
        ),
        final traffic => DashboardValue(
          value:
              '↓ ${formatBytes(traffic.receiveRate)}/s  '
              '↑ ${formatBytes(traffic.sendRate)}/s',
          supporting: context.l10n.homeTrafficTotals(
            formatBytes(traffic.received),
            formatBytes(traffic.sent),
          ),
        ),
      },
    ),
  );
}

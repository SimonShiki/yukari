import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/byte_units.dart';
import 'dashboard_card.dart';
import 'dashboard_skeleton.dart';
import 'dashboard_value.dart';

/// The current receive and send rates, and the totals they add up to.
class TrafficCard extends StatelessWidget {
  const TrafficCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DashboardCard(
      shape: Shapes.l4LeafClover,
      icon: Icons.swap_vert_rounded,
      title: l10n.homeTraffic,
      child: SignalBuilder(
        builder: (context) => DashboardValueSwitcher(child: _value(l10n)),
      ),
    );
  }

  Widget _value(AppLocalizations l10n) {
    if (!controller.refreshed.value) return const DashboardSkeleton();
    if (controller.trafficIdle.value) {
      return DashboardValue(
        value: l10n.homeNoTraffic,
        supporting: DashboardSupporting(l10n.homeNoRunningNetwork),
      );
    }
    // The arrows and /s are symbols, not translatable text.
    return DashboardValue(
      value:
          '↓ ${formatBytes(controller.receiveRate.value)}/s  '
          '↑ ${formatBytes(controller.sendRate.value)}/s',
      supporting: DashboardSupporting(
        l10n.homeTrafficTotals(
          formatBytes(controller.totalReceived.value),
          formatBytes(controller.totalSent.value),
        ),
      ),
    );
  }
}

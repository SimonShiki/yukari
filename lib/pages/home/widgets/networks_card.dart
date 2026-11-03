import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import 'dashboard_card.dart';
import 'dashboard_skeleton.dart';
import 'dashboard_value.dart';

/// How many saved networks run, and which ones.
class NetworksCard extends StatelessWidget {
  const NetworksCard({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final HomeController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DashboardCard(
      shape: Shapes.c9SidedCookie,
      icon: Icons.hub_rounded,
      title: l10n.navNetworks,
      onTap: onOpen,
      child: SignalBuilder(
        builder: (context) =>
            DashboardValueSwitcher(child: _value(context, l10n)),
      ),
    );
  }

  Widget _value(BuildContext context, AppLocalizations l10n) {
    if (!controller.refreshed.value) return const DashboardSkeleton();
    final saved = controller.savedCount.value;
    if (saved == 0) {
      return DashboardValue(
        value: l10n.homeNoNetworks,
        supporting: DashboardSupporting(l10n.homeCreateNetworkHint),
      );
    }
    final running = controller.runningCount.value;
    return DashboardValue(
      value: l10n.homeRunningNetworks(running, saved),
      supporting: DashboardSupporting(
        running == 0
            ? l10n.homeStartNetworkHint
            : controller.runningNames.value,
      ),
      tooltip: running > 1 ? controller.runningNamesMultiline.value : null,
    );
  }
}

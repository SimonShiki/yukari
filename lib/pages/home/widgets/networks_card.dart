import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../signals/networks.dart';
import 'dashboard_card.dart';

/// How many saved networks run, and which.
class NetworksCard extends StatelessWidget {
  const NetworksCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final saved = networks.value.length;
      final running = [
        for (final instance in controller.instances.value.values)
          instance.network.networkName,
      ];
      return DashboardCard(
        icon: Icons.hub_rounded,
        shape: Shapes.c9SidedCookie,
        title: 'Networks',
        onTap: () => context.go(saved == 0 ? '/networks/create' : '/networks'),
        child: !controller.refreshed.value
            ? const DashboardValue.loading()
            : saved == 0
            ? const DashboardValue(
                value: 'No networks',
                supporting: 'Tap to create one.',
              )
            : DashboardValue(
                value: '${running.length} of $saved running',
                supporting: running.isEmpty
                    ? 'Start one to connect.'
                    : running.join(', '),
                tooltip: running.length > 1 ? running.join('\n') : null,
              ),
      );
    },
  );
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/stun_probe.dart';
import 'dashboard_card.dart';

/// This device's address in the running networks, or its public address
/// while none runs.
class AddressCard extends StatelessWidget {
  const AddressCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final virtual = controller.virtualAddresses.value;
      // Which address to show depends on whether networks run.
      final refreshed = controller.refreshed.value;
      return DashboardCard(
        icon: Icons.location_on_rounded,
        shape: Shapes.pentagon,
        title: !refreshed
            ? context.l10n.homeIpAddress
            : virtual.isEmpty
            ? context.l10n.homePublicIp
            : context.l10n.homeVirtualIp,
        child: switch (virtual) {
          _ when !refreshed => const DashboardValue.loading(),
          [] => _public(context),
          [final first, ...final others] => DashboardValue(
            value: first.address,
            supporting: [
              ?first.host,
              first.network,
              if (others.isNotEmpty)
                context.l10n.homeMoreAddresses(others.length),
            ].join(' · '),
            // In full, as the line above can cut names off.
            tooltip: first.host == null && others.isEmpty
                ? null
                : [
                    for (final (:address, :host, :network) in virtual)
                      [address, ?host, network].join('  '),
                  ].join('\n'),
            selectable: true,
          ),
        },
      );
    },
  );

  Widget _public(BuildContext context) => switch (controller.natProbe.value) {
    null => const DashboardValue.loading(),
    NatProbe(publicAddress: final address?) => DashboardValue(
      value: address,
      supporting: context.l10n.homeSeenByStun,
      selectable: true,
    ),
    NatProbe() => DashboardValue(
      value: context.l10n.homeUnavailable,
      supporting: context.l10n.homeNoStunAnswer,
    ),
  };
}

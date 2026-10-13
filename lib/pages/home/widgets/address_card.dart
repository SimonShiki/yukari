import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
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
            ? 'IP address'
            : virtual.isEmpty
            ? 'Public IP'
            : 'Virtual IP',
        child: switch (virtual) {
          _ when !refreshed => const DashboardValue.loading(),
          [] => _public(),
          [final first, ...final others] => DashboardValue(
            value: first.address,
            supporting: [
              ?first.host,
              first.network,
              if (others.isNotEmpty) '+${others.length} more',
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

  Widget _public() => switch (controller.natProbe.value) {
    null => const DashboardValue.loading(),
    NatProbe(publicAddress: final address?) => DashboardValue(
      value: address,
      supporting: 'Seen by STUN servers',
      selectable: true,
    ),
    NatProbe() => const DashboardValue(
      value: 'Unavailable',
      supporting: 'No STUN server answered.',
    ),
  };
}

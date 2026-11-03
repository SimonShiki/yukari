import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import 'dashboard_card.dart';
import 'dashboard_skeleton.dart';
import 'dashboard_value.dart';

/// The virtual addresses of the running networks, or the public address STUN
/// reports when nothing runs.
class AddressCard extends StatelessWidget {
  const AddressCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) {
        final kind = controller.addressKind.value;
        return DashboardCard(
          shape: Shapes.pentagon,
          icon: Icons.location_on_rounded,
          title: switch (kind) {
            AddressKind.initial => l10n.homeIpAddress,
            AddressKind.virtual => l10n.homeVirtualIp,
            AddressKind.waiting ||
            AddressKind.public ||
            AddressKind.unavailable => l10n.homePublicIp,
          },
          child: DashboardValueSwitcher(child: _value(l10n, kind)),
        );
      },
    );
  }

  Widget _value(AppLocalizations l10n, AddressKind kind) => switch (kind) {
    AddressKind.initial || AddressKind.waiting => const DashboardSkeleton(),
    AddressKind.unavailable => DashboardValue(
      value: l10n.homeUnavailable,
      supporting: DashboardSupporting(l10n.homeNoStunAnswer),
    ),
    AddressKind.public => DashboardValue(
      value: controller.address.value ?? '',
      supporting: DashboardSupporting(l10n.homeSeenByStun),
      selectable: true,
    ),
    AddressKind.virtual => DashboardValue(
      value: controller.address.value ?? '',
      supporting: DashboardSupporting(_supporting(l10n)),
      tooltip: controller.addressTooltip.value,
      selectable: true,
    ),
  };

  /// `host · network · +N more`, the same order the card's tooltip lists.
  String _supporting(AppLocalizations l10n) {
    final more = controller.addressMoreCount.value;
    return [
      controller.addressSupporting.value,
      if (more > 0) l10n.homeMoreAddresses(more),
    ].join(' · ');
  }
}

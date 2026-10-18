import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/peer.dart';
import 'dashboard_card.dart';
import 'dashboard_skeleton.dart';
import 'dashboard_value.dart';

/// The NAT type EasyTier or STUN reported, and what it means for P2P.
class NatCard extends StatelessWidget {
  const NatCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DashboardCard(
      shape: Shapes.c6SidedCookie,
      icon: Icons.router_rounded,
      title: l10n.homeNatType,
      trailing: SignalBuilder(
        builder: (context) {
          // A type EasyTier reported needs no re-detection.
          if (controller.natReportedByEasytier.value) {
            return const SizedBox.shrink();
          }
          return DashboardAction(
            icon: Icons.refresh_rounded,
            tooltip: l10n.homeDetectAgain,
            onPressed: controller.probing.value ? null : controller.detectNat,
          );
        },
      ),
      child: SignalBuilder(
        builder: (context) {
          final nat = controller.natType.value;
          return DashboardValueSwitcher(
            child: nat == null
                ? const DashboardSkeleton()
                : _value(context, l10n, nat),
          );
        },
      ),
    );
  }

  Widget _value(BuildContext context, AppLocalizations l10n, NatType nat) {
    final p2p = _p2p(context, nat);
    return DashboardValue(
      value: _label(l10n, nat),
      tooltip: _description(l10n, nat),
      supporting: DashboardSupportingLine(
        icon: p2p.icon,
        label: p2p.label,
        color: p2p.color,
      ),
    );
  }
}

String _label(AppLocalizations l10n, NatType nat) => switch (nat) {
  NatType.unknown => l10n.homeNatUnknown,
  NatType.openInternet => l10n.homeNatOpenInternet,
  NatType.noPat => l10n.homeNatNoPat,
  NatType.fullCone => l10n.homeNatFullCone,
  NatType.restricted => l10n.homeNatRestricted,
  NatType.portRestricted => l10n.homeNatPortRestricted,
  NatType.symmetricEasyIncrement ||
  NatType.symmetricEasyDecrement => l10n.homeNatPredictableSymmetric,
  NatType.symmetric => l10n.homeNatSymmetric,
  NatType.symmetricUdpFirewall => l10n.homeNatSymmetricFirewall,
};

String _description(AppLocalizations l10n, NatType nat) => switch (nat) {
  NatType.unknown => l10n.homeNatUnknownDescription,
  NatType.openInternet => l10n.homeNatOpenInternetDescription,
  NatType.noPat => l10n.homeNatNoPatDescription,
  NatType.fullCone => l10n.homeNatFullConeDescription,
  NatType.restricted => l10n.homeNatRestrictedDescription,
  NatType.portRestricted => l10n.homeNatPortRestrictedDescription,
  NatType.symmetricEasyIncrement ||
  NatType.symmetricEasyDecrement => l10n.homeNatPredictableSymmetricDescription,
  NatType.symmetric => l10n.homeNatSymmetricDescription,
  NatType.symmetricUdpFirewall => l10n.homeNatSymmetricFirewallDescription,
};

/// How well peers can reach this device, and how to color that.
({String label, IconData icon, Color color}) _p2p(
  BuildContext context,
  NatType nat,
) {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  return switch (nat) {
    NatType.unknown => (
      label: l10n.homeP2pUnknown,
      icon: Icons.help_outline,
      color: scheme.onSurfaceVariant,
    ),
    NatType.openInternet ||
    NatType.noPat ||
    NatType.fullCone ||
    NatType.restricted => (
      label: l10n.homeP2pEasy,
      icon: Icons.bolt_rounded,
      color: scheme.primary,
    ),
    NatType.portRestricted ||
    NatType.symmetricEasyIncrement ||
    NatType.symmetricEasyDecrement => (
      label: l10n.homeP2pFair,
      icon: Icons.swap_horiz_rounded,
      color: scheme.tertiary,
    ),
    NatType.symmetric || NatType.symmetricUdpFirewall => (
      label: l10n.homeP2pHard,
      icon: Icons.alt_route_rounded,
      color: scheme.error,
    ),
  };
}

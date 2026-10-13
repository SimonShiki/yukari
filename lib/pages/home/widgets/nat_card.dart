import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/peer.dart';
import 'dashboard_card.dart';

/// How readily peers behind a NAT type connect to this device directly,
/// rather than through relays.
enum _Ease {
  easy(Icons.bolt_rounded),
  fair(Icons.swap_horiz_rounded),
  hard(Icons.alt_route_rounded),
  unknown(Icons.help_outline_rounded);

  const _Ease(this.icon);

  final IconData icon;
  String summary(BuildContext context) => switch (this) {
    easy => context.l10n.homeP2pEasy,
    fair => context.l10n.homeP2pFair,
    hard => context.l10n.homeP2pHard,
    unknown => context.l10n.homeP2pUnknown,
  };

  Color color(ColorScheme colors) => switch (this) {
    easy => colors.primary,
    fair => colors.tertiary,
    hard => colors.error,
    unknown => colors.onSurfaceVariant,
  };
}

/// How this device's NAT treats UDP, and so how readily peers connect to it
/// directly.
class NatCard extends StatelessWidget {
  const NatCard({super.key, required this.controller});

  final HomeController controller;

  /// The type's name, how it behaves, and what that means for P2P.
  static (String, String, _Ease) _describe(
    BuildContext context,
    NatType type,
  ) => switch (type) {
    NatType.unknown => (
      context.l10n.homeNatUnknown,
      context.l10n.homeNatUnknownDescription,
      _Ease.unknown,
    ),
    NatType.openInternet => (
      context.l10n.homeNatOpenInternet,
      context.l10n.homeNatOpenInternetDescription,
      _Ease.easy,
    ),
    NatType.noPat => (
      context.l10n.homeNatNoPat,
      context.l10n.homeNatNoPatDescription,
      _Ease.easy,
    ),
    NatType.fullCone => (
      context.l10n.homeNatFullCone,
      context.l10n.homeNatFullConeDescription,
      _Ease.easy,
    ),
    NatType.restricted => (
      context.l10n.homeNatRestricted,
      context.l10n.homeNatRestrictedDescription,
      _Ease.easy,
    ),
    NatType.portRestricted => (
      context.l10n.homeNatPortRestricted,
      context.l10n.homeNatPortRestrictedDescription,
      _Ease.fair,
    ),
    NatType.symmetricEasyIncrement || NatType.symmetricEasyDecrement => (
      context.l10n.homeNatPredictableSymmetric,
      context.l10n.homeNatPredictableSymmetricDescription,
      _Ease.fair,
    ),
    NatType.symmetric => (
      context.l10n.homeNatSymmetric,
      context.l10n.homeNatSymmetricDescription,
      _Ease.hard,
    ),
    NatType.symmetricUdpFirewall => (
      context.l10n.homeNatSymmetricFirewall,
      context.l10n.homeNatSymmetricFirewallDescription,
      _Ease.hard,
    ),
  };

  static Widget _report(
    BuildContext context,
    NatType type,
    ColorScheme colors,
  ) {
    final (label, behavior, ease) = _describe(context, type);
    return DashboardValue(
      value: label,
      supporting: ease.summary(context),
      supportingIcon: ease.icon,
      supportingColor: ease.color(colors),
      tooltip: behavior,
    );
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      final nat = controller.nat.value;
      final probing = controller.probing.value;
      return DashboardCard(
        icon: Icons.router_rounded,
        shape: Shapes.c6SidedCookie,
        title: context.l10n.homeNatType,
        // EasyTier keeps its report current; the probe needs a rerun.
        trailing: nat?.reported ?? false
            ? null
            : DashboardAction(
                icon: Icons.refresh_rounded,
                tooltip: context.l10n.homeDetectAgain,
                onPressed: probing ? null : controller.detectNat,
              ),
        child: switch (nat) {
          null => const DashboardValue.loading(),
          (:final type, reported: _) => _report(context, type, colors),
        },
      );
    },
  );
}

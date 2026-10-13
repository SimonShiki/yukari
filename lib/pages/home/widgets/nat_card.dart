import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../models/peer.dart';
import 'dashboard_card.dart';

/// How readily peers behind a NAT type connect to this device directly,
/// rather than through relays.
enum _Ease {
  easy(Icons.bolt_rounded, 'Easy P2P · connects directly'),
  fair(Icons.swap_horiz_rounded, 'Fair P2P · usually direct'),
  hard(Icons.alt_route_rounded, 'Hard P2P · often relayed'),
  unknown(Icons.help_outline_rounded, 'P2P unknown · UDP may be blocked');

  const _Ease(this.icon, this.summary);

  final IconData icon;
  final String summary;

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
  static (String, String, _Ease) _describe(NatType type) => switch (type) {
    NatType.unknown => (
      'Unknown',
      'No STUN server could tell how this network maps UDP.',
      _Ease.unknown,
    ),
    NatType.openInternet => (
      'Open internet',
      'This device has a public address with no NAT or firewall.',
      _Ease.easy,
    ),
    NatType.noPat => (
      'No NAT',
      'A public address, behind a firewall that filters UDP.',
      _Ease.easy,
    ),
    NatType.fullCone => (
      'Full cone',
      'Anyone can reach the public port this device sends from.',
      _Ease.easy,
    ),
    NatType.restricted => (
      'Restricted cone',
      'Hosts this device contacted can reach it, from any port.',
      _Ease.easy,
    ),
    NatType.portRestricted => (
      'Port restricted cone',
      'Only the exact addresses and ports contacted can reach back.',
      _Ease.fair,
    ),
    NatType.symmetricEasyIncrement || NatType.symmetricEasyDecrement => (
      'Predictable symmetric',
      'Each peer sees another port, but in an order EasyTier can guess.',
      _Ease.fair,
    ),
    NatType.symmetric => (
      'Symmetric',
      'Each peer sees another public port, which is hard to punch through.',
      _Ease.hard,
    ),
    NatType.symmetricUdpFirewall => (
      'Symmetric firewall',
      'A firewall gives each peer another port, which is hard to punch through.',
      _Ease.hard,
    ),
  };

  static Widget _report(NatType type, ColorScheme colors) {
    final (label, behavior, ease) = _describe(type);
    return DashboardValue(
      value: label,
      supporting: ease.summary,
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
        title: 'NAT type',
        // EasyTier keeps its report current; the probe needs a rerun.
        trailing: nat?.reported ?? false
            ? null
            : DashboardAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Detect again',
                onPressed: probing ? null : controller.detectNat,
              ),
        child: switch (nat) {
          null => const DashboardValue.loading(),
          (:final type, reported: _) => _report(type, colors),
        },
      );
    },
  );
}

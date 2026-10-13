import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network.dart';
import '../../../utils/line_formats.dart';
import '../../../utils/validator.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// Subnet proxy, routes, exit nodes and port forwarding.
class RoutingSection extends StatelessWidget {
  const RoutingSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedRouting,
      icon: Icons.alt_route,
      description: l10n.advancedRoutingDescription,
      children: [
        LineListField(
          label: l10n.advancedSubnetProxy,
          hint: l10n.advancedSubnetProxyHint,
          helper: l10n.advancedSubnetProxyHelper,
          initial: _network.proxyNetworks.map(formatProxyNetwork),
          validateLine: validateProxyNetwork,
          onValid: (lines) => controller.update((n) {
            // Keep the allow lists, which have no text form, of kept networks.
            final allow = {for (final p in n.proxyNetworks) p.cidr: p.allow};
            n.proxyNetworks = [
              for (final proxy in lines.map(parseProxyNetwork))
                proxy..allow = allow[proxy.cidr] ?? [],
            ];
          }),
        ),
        LineListField(
          label: l10n.advancedManualRoutes,
          hint: '192.168.0.0/16',
          helper: l10n.advancedManualRoutesHelper,
          initial: _network.routes,
          validateLine: validateIpv4Network,
          onValid: (lines) => controller.update((n) => n.routes = lines),
        ),
        LineListField(
          label: l10n.advancedExitNodes,
          hint: '10.144.144.1',
          helper: l10n.advancedExitNodesHelper,
          initial: _network.exitNodes,
          validateLine: validateIp,
          onValid: (lines) => controller.update((n) => n.exitNodes = lines),
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedEnableExitNode,
          subtitle: l10n.advancedEnableExitNodeSubtitle,
          read: (f) => f.enableExitNode,
          write: (f, v) => f.enableExitNode = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedSystemForwarding,
          subtitle: l10n.advancedSystemForwardingSubtitle,
          read: (f) => f.proxyForwardBySystem,
          write: (f, v) => f.proxyForwardBySystem = v,
        ),
        LineListField(
          label: l10n.advancedPortForwarding,
          hint: 'udp://0.0.0.0:12345/10.144.144.2:23456',
          helper: l10n.advancedPortForwardingHelper,
          initial: _network.portForwards.map(formatPortForward),
          validateLine: validatePortForward,
          onValid: (lines) => controller.update(
            (n) =>
                n.portForwards = lines.map(parsePortForward).nonNulls.toList(),
          ),
        ),
      ],
    );
  }
}

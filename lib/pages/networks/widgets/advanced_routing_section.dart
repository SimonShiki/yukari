import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../utils/line_formats.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Routing: what this node shares, where its traffic goes, and the ports it
/// forwards.
class AdvancedRoutingSection extends StatelessWidget {
  const AdvancedRoutingSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedRouting,
      icon: Icons.alt_route,
      description: l10n.advancedRoutingDescription,
      children: [
        EditorLinesField(
          label: l10n.advancedSubnetProxy,
          helper: l10n.advancedSubnetProxyHelper,
          hint: l10n.advancedSubnetProxyHint,
          initialValue: network.proxyNetworks.map(formatProxyNetwork).join('\n'),
          validateLine: validateProxyNetwork,
          onSaved: (lines) => controller.update(
            (n) => n.proxyNetworks = [
              for (final line in lines)
                _keepAllow(parseProxyNetwork(line), n.proxyNetworks),
            ],
          ),
        ),
        EditorLinesField(
          label: l10n.advancedManualRoutes,
          helper: l10n.advancedManualRoutesHelper,
          hint: '192.168.0.0/16',
          initialValue: network.routes.join('\n'),
          validateLine: validateIpv4Network,
          onSaved: (lines) => controller.update((n) => n.routes = lines),
        ),
        EditorLinesField(
          label: l10n.advancedExitNodes,
          helper: l10n.advancedExitNodesHelper,
          hint: '10.144.144.1',
          initialValue: network.exitNodes.join('\n'),
          validateLine: validateIp,
          onSaved: (lines) => controller.update((n) => n.exitNodes = lines),
        ),
        EditorSwitch(
          controller: controller,
          name: 'flags.enableExitNode',
          read: (n) => n.flags.enableExitNode,
          write: (n, value) => n.flags.enableExitNode = value,
          title: l10n.advancedEnableExitNode,
          subtitle: l10n.advancedEnableExitNodeSubtitle,
        ),
        EditorSwitch(
          controller: controller,
          name: 'flags.proxyForwardBySystem',
          read: (n) => n.flags.proxyForwardBySystem,
          write: (n, value) => n.flags.proxyForwardBySystem = value,
          title: l10n.advancedSystemForwarding,
          subtitle: l10n.advancedSystemForwardingSubtitle,
        ),
        EditorLinesField(
          label: l10n.advancedPortForwarding,
          helper: l10n.advancedPortForwardingHelper,
          hint: 'udp://0.0.0.0:12345/10.144.144.2:23456',
          initialValue: network.portForwards.map(formatPortForward).join('\n'),
          validateLine: validatePortForward,
          onSaved: (lines) => controller.update(
            (n) => n.portForwards = lines.map(parsePortForward).nonNulls.toList(),
          ),
        ),
      ],
    );
  }

  /// A rewritten subnet proxy line keeps the CIDR's existing allow list.
  static ProxyNetwork _keepAllow(
    ProxyNetwork proxy,
    List<ProxyNetwork> existing,
  ) {
    for (final entry in existing) {
      if (entry.cidr == proxy.cidr) {
        proxy.allow = entry.allow;
        break;
      }
    }
    return proxy;
  }
}

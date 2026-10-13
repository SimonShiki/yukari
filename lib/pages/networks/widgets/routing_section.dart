import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
import '../../../utils/line_formats.dart';
import '../../../utils/validator.dart';
import 'network_fields.dart';
import 'network_form_section.dart';

/// Subnet proxy, routes, exit nodes and port forwarding.
class RoutingSection extends StatelessWidget {
  const RoutingSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Routing',
    icon: Icons.alt_route,
    description: 'Share local networks and choose where traffic goes',
    children: [
      LineListField(
        label: 'Subnet Proxy',
        hint: '192.168.1.0/24 or 192.168.1.0/24->10.1.1.0/24',
        helper:
            'Local IPv4 networks to share with peers, optionally mapped to '
            'another network of the same size',
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
        label: 'Manual Routes',
        hint: '192.168.0.0/16',
        helper:
            'Route only these IPv4 networks; ignores subnet proxy and '
            'WireGuard routes from peers. Leave empty to accept them',
        initial: _network.routes,
        validateLine: validateIpv4Network,
        onValid: (lines) => controller.update((n) => n.routes = lines),
      ),
      LineListField(
        label: 'Exit Nodes',
        hint: '10.144.144.1',
        helper:
            'Virtual IPs of peers to send all traffic through, in order of '
            'priority',
        initial: _network.exitNodes,
        validateLine: validateIp,
        onValid: (lines) => controller.update((n) => n.exitNodes = lines),
      ),
      FlagSwitch(
        controller: controller,
        title: 'Enable Exit Node',
        subtitle: 'Allow peers to use this node as an exit node',
        read: (f) => f.enableExitNode,
        write: (f, v) => f.enableExitNode = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'System Forwarding',
        subtitle:
            'Forward proxied traffic through the system kernel instead of '
            'the built-in NAT',
        read: (f) => f.proxyForwardBySystem,
        write: (f, v) => f.proxyForwardBySystem = v,
      ),
      LineListField(
        label: 'Port Forwarding',
        hint: 'udp://0.0.0.0:12345/10.144.144.2:23456',
        helper: 'Forward a local port to an address in the virtual network',
        initial: _network.portForwards.map(formatPortForward),
        validateLine: validatePortForward,
        onValid: (lines) => controller.update(
          (n) => n.portForwards = lines.map(parsePortForward).nonNulls.toList(),
        ),
      ),
    ],
  );
}

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// How this node connects directly to peers.
class P2pSection extends StatelessWidget {
  const P2pSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) => FormSection(
    title: 'P2P & NAT Traversal',
    icon: Icons.hub,
    description: 'Direct connections and hole punching',
    collapsible: true,
    children: [
      FlagSwitch(
        controller: controller,
        title: 'Disable P2P',
        subtitle:
            'Only relay through other nodes; peers that need P2P can still '
            'connect directly',
        read: (f) => f.disableP2p,
        write: (f, v) => f.disableP2p = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'P2P Only',
        subtitle: 'Only talk to peers with a direct connection, never relay',
        read: (f) => f.p2pOnly,
        write: (f, v) => f.p2pOnly = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Lazy P2P',
        subtitle: 'Connect directly to a peer only once traffic targets it',
        read: (f) => f.lazyP2p,
        write: (f, v) => f.lazyP2p = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Need P2P',
        subtitle: 'Ask peers to connect to this node directly, even if lazy',
        read: (f) => f.needP2p,
        write: (f, v) => f.needP2p = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable UDP Hole Punching',
        subtitle: 'Do not punch through NAT over UDP',
        read: (f) => f.disableUdpHolePunching,
        write: (f, v) => f.disableUdpHolePunching = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable TCP Hole Punching',
        subtitle: 'Do not punch through NAT over TCP',
        read: (f) => f.disableTcpHolePunching,
        write: (f, v) => f.disableTcpHolePunching = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable Symmetric NAT Hole Punching',
        subtitle: 'Treat symmetric NAT as cone NAT',
        read: (f) => f.disableSymmetricHolePunching,
        write: (f, v) => f.disableSymmetricHolePunching = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable UPnP',
        subtitle: 'Do not map listener ports with UPnP or NAT-PMP',
        read: (f) => f.disableUpnp,
        write: (f, v) => f.disableUpnp = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Bind to Physical Device Only',
        subtitle: 'Never connect to peers through other virtual networks',
        read: (f) => f.bindDevice,
        write: (f, v) => f.bindDevice = v,
      ),
    ],
  );
}

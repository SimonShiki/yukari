import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import 'form_segments.dart';
import 'network_fields.dart';
import 'network_form_section.dart';
import 'validated_text_field.dart';

/// What this node forwards for other peers and networks.
class RelaySection extends StatelessWidget {
  const RelaySection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Relay',
    icon: Icons.swap_calls,
    description: 'Forwarding traffic for other peers and networks',
    collapsible: true,
    children: [
      FieldSegment(
        child: ValidatedTextField(
          initialValue: controller.network.peek()!.flags.relayNetworkWhitelist,
          decoration: const InputDecoration(
            labelText: 'Relay Network Whitelist',
            hintText: '*',
            helperText:
                'Networks to relay, separated by spaces; wildcards allowed. '
                'Leave empty to relay none',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
          onValid: (v) => controller.update(
            (n) => n.flags.relayNetworkWhitelist = v.trim(),
          ),
        ),
      ),
      FlagSwitch(
        controller: controller,
        title: 'Relay All Peer RPC',
        subtitle:
            'Relay RPC of peers outside the whitelist so they can set up P2P',
        read: (f) => f.relayAllPeerRpc,
        write: (f, v) => f.relayAllPeerRpc = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable Data Relay',
        subtitle: 'Carry no data packets for other peers',
        read: (f) => f.disableRelayData,
        write: (f, v) => f.disableRelayData = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Prefer Peer Relay',
        subtitle: 'Prefer credential peers already relaying to a destination',
        read: (f) => f.preferPeerRelay,
        write: (f, v) => f.preferPeerRelay = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable KCP Relay',
        subtitle: 'Do not relay KCP packets, to save bandwidth',
        read: (f) => f.disableRelayKcp,
        write: (f, v) => f.disableRelayKcp = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Relay Foreign Network KCP',
        subtitle:
            'Relay KCP packets of other networks when serving as a shared node',
        read: (f) => f.enableRelayForeignNetworkKcp,
        write: (f, v) => f.enableRelayForeignNetworkKcp = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Disable QUIC Relay',
        subtitle: 'Do not relay QUIC packets, to save bandwidth',
        read: (f) => f.disableRelayQuic,
        write: (f, v) => f.disableRelayQuic = v,
      ),
      FlagSwitch(
        controller: controller,
        title: 'Relay Foreign Network QUIC',
        subtitle: 'Relay QUIC packets of other networks when serving as a shared node',
        read: (f) => f.enableRelayForeignNetworkQuic,
        write: (f, v) => f.enableRelayForeignNetworkQuic = v,
      ),
      OptionalIntField(
        label: 'Foreign Relay Limit',
        helper:
            'Bytes per second relayed for other networks. Leave empty for no '
            'limit',
        initial: controller.network.peek()!.flags.foreignRelayBpsLimit,
        min: 1,
        max: 0x7fffffffffffffff,
        onValid: (v) =>
            controller.update((n) => n.flags.foreignRelayBpsLimit = v),
      ),
      FlagSwitch(
        controller: controller,
        title: 'UDP Broadcast Relay',
        subtitle:
            'Windows only: forward local UDP broadcasts to peers, so games find '
            'LAN rooms. Needs administrator rights',
        read: (f) => f.enableUdpBroadcastRelay,
        write: (f, v) => f.enableUdpBroadcastRelay = v,
      ),
    ],
  );
}

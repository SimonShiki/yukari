import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
import '../../../utils/validator.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// STUN servers used to discover this node's public address.
class StunSection extends StatelessWidget {
  const StunSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) => FormSection(
    title: 'STUN Servers',
    icon: Icons.cloud_sync,
    description: 'STUN servers for NAT traversal. Leave empty for defaults',
    collapsible: true,
    children: [
      LineListField(
        label: 'STUN Servers',
        hint: 'stun.example.com:3478',
        helper: 'UDP STUN servers, also used for TCP when that is empty',
        initial: _network.stunServers,
        validateLine: validateStunServer,
        onValid: (lines) => controller.update((n) => n.stunServers = lines),
      ),
      LineListField(
        label: 'TCP STUN Servers',
        hint: 'stun.example.com:3478',
        helper: 'STUN servers queried over TCP',
        initial: _network.tcpStunServers,
        validateLine: validateStunServer,
        onValid: (lines) => controller.update((n) => n.tcpStunServers = lines),
      ),
      LineListField(
        label: 'IPv6 STUN Servers',
        hint: 'stun.example.com:3478',
        helper:
            'STUN servers queried over IPv6. Off when empty while STUN '
            'Servers is set',
        initial: _network.stunServersV6,
        validateLine: validateStunServer,
        onValid: (lines) => controller.update((n) => n.stunServersV6 = lines),
      ),
    ],
  );
}

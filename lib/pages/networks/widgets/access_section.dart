import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
import '../../../utils/validator.dart';
import 'network_fields.dart';
import 'network_form_section.dart';

/// Who may reach this node and through which ports.
class AccessSection extends StatelessWidget {
  const AccessSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Access Control',
    icon: Icons.shield,
    description: 'Restrict other networks and open ports',
    collapsible: true,
    children: [
      FlagSwitch(
        controller: controller,
        title: 'Private Mode',
        subtitle:
            'Refuse handshakes and relaying for nodes of other networks or '
            'with another secret',
        read: (f) => f.privateMode,
        write: (f, v) => f.privateMode = v,
      ),
      LineListField(
        label: 'TCP Port Whitelist',
        hint: '80 or 8000-9000',
        helper: 'TCP ports peers may reach. Leave empty to allow all',
        initial: _network.tcpWhitelist,
        validateLine: validatePortRange,
        onValid: (lines) => controller.update((n) => n.tcpWhitelist = lines),
      ),
      LineListField(
        label: 'UDP Port Whitelist',
        hint: '53 or 5000-6000',
        helper: 'UDP ports peers may reach. Leave empty to allow all',
        initial: _network.udpWhitelist,
        validateLine: validatePortRange,
        onValid: (lines) => controller.update((n) => n.udpWhitelist = lines),
      ),
    ],
  );
}

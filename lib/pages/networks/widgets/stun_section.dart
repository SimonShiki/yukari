import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network.dart';
import '../../../controllers/network_editor_validator.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// STUN servers used to discover this node's public address.
class StunSection extends StatelessWidget {
  const StunSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedStunServers,
      icon: Icons.cloud_sync,
      description: l10n.advancedStunDescription,
      collapsible: true,
      children: [
        LineListField(
          label: l10n.advancedStunServers,
          hint: 'stun.example.com:3478',
          helper: l10n.advancedStunServersHelper,
          initial: _network.stunServers,
          validateLine: validateStunServer,
          onValid: (lines) => controller.update((n) => n.stunServers = lines),
        ),
        LineListField(
          label: l10n.advancedTcpStunServers,
          hint: 'stun.example.com:3478',
          helper: l10n.advancedTcpStunServersHelper,
          initial: _network.tcpStunServers,
          validateLine: validateStunServer,
          onValid: (lines) =>
              controller.update((n) => n.tcpStunServers = lines),
        ),
        LineListField(
          label: l10n.advancedIpv6StunServers,
          hint: 'stun.example.com:3478',
          helper: l10n.advancedIpv6StunServersHelper,
          initial: _network.stunServersV6,
          validateLine: validateStunServer,
          onValid: (lines) => controller.update((n) => n.stunServersV6 = lines),
        ),
      ],
    );
  }
}

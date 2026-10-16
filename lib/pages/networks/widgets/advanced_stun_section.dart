import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// STUN Servers, for NAT traversal.
class AdvancedStunSection extends StatelessWidget {
  const AdvancedStunSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    const hint = 'stun.example.com:3478';
    return FormSection(
      title: l10n.advancedStunServers,
      icon: Icons.cloud_sync,
      description: l10n.advancedStunDescription,
      collapsible: true,
      children: [
        EditorLinesField(
          label: l10n.advancedStunServers,
          helper: l10n.advancedStunServersHelper,
          hint: hint,
          initialValue: network.stunServers.join('\n'),
          validateLine: validateStunServer,
          onSaved: (lines) => controller.update((n) => n.stunServers = lines),
        ),
        EditorLinesField(
          label: l10n.advancedTcpStunServers,
          helper: l10n.advancedTcpStunServersHelper,
          hint: hint,
          initialValue: network.tcpStunServers.join('\n'),
          validateLine: validateStunServer,
          onSaved: (lines) => controller.update((n) => n.tcpStunServers = lines),
        ),
        EditorLinesField(
          label: l10n.advancedIpv6StunServers,
          helper: l10n.advancedIpv6StunServersHelper,
          hint: hint,
          initialValue: network.stunServersV6.join('\n'),
          validateLine: validateStunServer,
          onSaved: (lines) => controller.update((n) => n.stunServersV6 = lines),
        ),
      ],
    );
  }
}

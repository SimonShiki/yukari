import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network.dart';
import '../../../controllers/network_editor_validator.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// Who may reach this node and through which ports.
class AccessSection extends StatelessWidget {
  const AccessSection({super.key, required this.controller});

  final NetworkEditorController controller;

  Network get _network => controller.network.peek()!;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedAccessControl,
      icon: Icons.shield,
      description: l10n.advancedAccessControlDescription,
      collapsible: true,
      children: [
        FlagSwitch(
          controller: controller,
          title: l10n.advancedPrivateMode,
          subtitle: l10n.advancedPrivateModeSubtitle,
          read: (f) => f.privateMode,
          write: (f, v) => f.privateMode = v,
        ),
        LineListField(
          label: l10n.advancedTcpWhitelist,
          hint: l10n.advancedTcpWhitelistHint,
          helper: l10n.advancedTcpWhitelistHelper,
          initial: _network.tcpWhitelist,
          validateLine: validatePortRange,
          onValid: (lines) => controller.update((n) => n.tcpWhitelist = lines),
        ),
        LineListField(
          label: l10n.advancedUdpWhitelist,
          hint: l10n.advancedUdpWhitelistHint,
          helper: l10n.advancedUdpWhitelistHelper,
          initial: _network.udpWhitelist,
          validateLine: validatePortRange,
          onValid: (lines) => controller.update((n) => n.udpWhitelist = lines),
        ),
      ],
    );
  }
}

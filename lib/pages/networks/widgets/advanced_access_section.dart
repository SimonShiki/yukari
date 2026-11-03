import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Access Control: private mode and the port whitelists.
class AdvancedAccessSection extends StatelessWidget {
  const AdvancedAccessSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedAccessControl,
      icon: Icons.shield,
      description: l10n.advancedAccessControlDescription,
      collapsible: true,
      children: [
        EditorSwitch(
          icon: Icons.lock_outline_rounded,
          controller: controller,
          name: 'flags.privateMode',
          read: (n) => n.flags.privateMode,
          write: (n, value) => n.flags.privateMode = value,
          title: l10n.advancedPrivateMode,
          subtitle: l10n.advancedPrivateModeSubtitle,
        ),
        EditorLinesField(
          label: l10n.advancedTcpWhitelist,
          helper: l10n.advancedTcpWhitelistHelper,
          hint: l10n.advancedTcpWhitelistHint,
          initialValue: network.tcpWhitelist.join('\n'),
          validateLine: validatePortRange,
          onSaved: (lines) => controller.update((n) => n.tcpWhitelist = lines),
        ),
        EditorLinesField(
          label: l10n.advancedUdpWhitelist,
          helper: l10n.advancedUdpWhitelistHelper,
          hint: l10n.advancedUdpWhitelistHint,
          initialValue: network.udpWhitelist.join('\n'),
          validateLine: validatePortRange,
          onSaved: (lines) => controller.update((n) => n.udpWhitelist = lines),
        ),
      ],
    );
  }
}

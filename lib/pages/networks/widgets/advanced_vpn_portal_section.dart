import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../controllers/network_editor_security.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'editor_fields.dart';

/// VPN Portal: WireGuard clients joining without EasyTier.
class AdvancedVpnPortalSection extends StatelessWidget {
  const AdvancedVpnPortalSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = controller.select(
      'vpnPortal.enabled',
      (n) => n.vpnPortal?.enabled ?? false,
      false,
    );
    final listen = controller.select(
      'vpnPortal.listen',
      (n) => n.vpnPortal?.wireguardListen ?? '',
      '',
    );
    return FormSection(
      title: l10n.advancedVpnPortal,
      icon: Icons.vpn_lock,
      description: l10n.advancedVpnPortalDescription,
      collapsible: true,
      children: [
        SignalBuilder(
          builder: (context) => SwitchSegment(
            icon: Icons.vpn_lock_rounded,
            title: l10n.advancedEnableVpnPortal,
            subtitle: l10n.advancedEnableVpnPortalSubtitle,
            value: enabled.value,
            onChanged: controller.setVpnPortal,
          ),
        ),
        SignalBuilder(
          builder: (context) => EditorTextField(
            key: const ValueKey('wireguardListen'),
            label: l10n.advancedWireguardListen,
            hint: '0.0.0.0:22022',
            helper: l10n.advancedWireguardListenHelper,
            value: listen.value,
            enabled: enabled.value,
            validator: validateSocketAddress,
            onSaved: (value) => controller.setWireguardListen(value.trim()),
          ),
        ),
      ],
    );
  }
}

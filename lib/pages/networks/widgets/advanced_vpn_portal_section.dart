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
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final enabled = controller
          .select('vpnPortal.enabled', (n) => n.vpnPortal?.enabled ?? false, false)
          .value;
      return FormSection(
        title: l10n.advancedVpnPortal,
        icon: Icons.vpn_lock,
        description: l10n.advancedVpnPortalDescription,
        collapsible: true,
        children: [
          SwitchSegment(
            title: l10n.advancedEnableVpnPortal,
            subtitle: l10n.advancedEnableVpnPortalSubtitle,
            value: enabled,
            onChanged: controller.setVpnPortal,
          ),
          SignalBuilder(
            builder: (context) => EditorTextField(
              key: const ValueKey('wireguardListen'),
              label: l10n.advancedWireguardListen,
              hint: '0.0.0.0:22022',
              helper: l10n.advancedWireguardListenHelper,
              initialValue: controller
                  .select(
                    'vpnPortal.listen',
                    (n) => n.vpnPortal?.wireguardListen ?? '',
                    '',
                  )
                  .value,
              value: controller
                  .select(
                    'vpnPortal.listen',
                    (n) => n.vpnPortal?.wireguardListen ?? '',
                    '',
                  )
                  .value,
              enabled: enabled,
              validator: validateSocketAddress,
              onSaved: (value) => controller.setWireguardListen(value.trim()),
            ),
          ),
        ],
      );
    },
  );
}

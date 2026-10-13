import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network_components.dart';
import '../../../utils/crypto_utils.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/form_section/form_section.dart';
import 'validated_text_field.dart';

const _defaultListen = '0.0.0.0:22022';

/// The WireGuard portal letting plain WireGuard clients join the network.
class VpnPortalSection extends StatelessWidget {
  const VpnPortalSection({super.key, required this.controller});

  final NetworkEditorController controller;

  bool get _enabled => controller.network.value!.vpnPortal?.enabled ?? false;

  void _setEnabled(bool enabled) => controller.update((n) {
    // The portal cannot start without its own WireGuard key.
    final portal = n.vpnPortal ??= VpnPortal(wireguardListen: _defaultListen);
    portal.enabled = enabled;
    if (enabled) portal.wireguardPrivateKey ??= generatePrivateKey();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedVpnPortal,
      icon: Icons.vpn_lock,
      description: l10n.advancedVpnPortalDescription,
      collapsible: true,
      children: [
        SignalBuilder(
          builder: (context) => SwitchSegment(
            title: l10n.advancedEnableVpnPortal,
            subtitle: l10n.advancedEnableVpnPortalSubtitle,
            value: _enabled,
            onChanged: _setEnabled,
          ),
        ),
        FieldSegment(
          child: SignalBuilder(
            builder: (context) => ValidatedTextField(
              initialValue:
                  controller.network.peek()!.vpnPortal?.wireguardListen ??
                  _defaultListen,
              decoration: InputDecoration(
                labelText: l10n.advancedWireguardListen,
                hintText: _defaultListen,
                helperText: l10n.advancedWireguardListenHelper,
                border: const OutlineInputBorder(),
              ),
              enabled: _enabled,
              validator: validateSocketAddress,
              onValid: (v) => controller.update(
                (n) => n.vpnPortal?.wireguardListen = v.trim(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

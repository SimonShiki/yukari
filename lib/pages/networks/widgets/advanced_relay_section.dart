import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Relay: forwarding traffic for other peers and networks.
class AdvancedRelaySection extends StatelessWidget {
  const AdvancedRelaySection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedRelay,
      icon: Icons.swap_calls,
      description: l10n.advancedRelayDescription,
      collapsible: true,
      children: [
        // No validator: the whitelist takes spaces and wildcards.
        EditorTextField(
          label: l10n.advancedRelayWhitelist,
          hint: '*',
          helper: l10n.advancedRelayWhitelistHelper,
          initialValue: network.flags.relayNetworkWhitelist,
          onSaved: (value) => controller.update(
            (n) => n.flags.relayNetworkWhitelist = value.trim(),
          ),
        ),
        EditorSwitch(
          icon: Icons.hub_rounded,
          controller: controller,
          name: 'flags.relayAllPeerRpc',
          read: (n) => n.flags.relayAllPeerRpc,
          write: (n, value) => n.flags.relayAllPeerRpc = value,
          title: l10n.advancedRelayAllPeerRpc,
          subtitle: l10n.advancedRelayAllPeerRpcSubtitle,
        ),
        EditorSwitch(
          icon: Icons.cloud_off_outlined,
          controller: controller,
          name: 'flags.disableRelayData',
          read: (n) => n.flags.disableRelayData,
          write: (n, value) => n.flags.disableRelayData = value,
          title: l10n.advancedDisableRelayData,
          subtitle: l10n.advancedDisableRelayDataSubtitle,
        ),
        EditorSwitch(
          icon: Icons.compare_arrows_rounded,
          controller: controller,
          name: 'flags.preferPeerRelay',
          read: (n) => n.flags.preferPeerRelay,
          write: (n, value) => n.flags.preferPeerRelay = value,
          title: l10n.advancedPreferPeerRelay,
          subtitle: l10n.advancedPreferPeerRelaySubtitle,
        ),
        EditorSwitch(
          icon: Icons.speed_rounded,
          controller: controller,
          name: 'flags.disableRelayKcp',
          read: (n) => n.flags.disableRelayKcp,
          write: (n, value) => n.flags.disableRelayKcp = value,
          title: l10n.advancedDisableRelayKcp,
          subtitle: l10n.advancedDisableRelayKcpSubtitle,
        ),
        EditorSwitch(
          icon: Icons.public_rounded,
          controller: controller,
          name: 'flags.enableRelayForeignNetworkKcp',
          read: (n) => n.flags.enableRelayForeignNetworkKcp,
          write: (n, value) => n.flags.enableRelayForeignNetworkKcp = value,
          title: l10n.advancedRelayForeignKcp,
          subtitle: l10n.advancedRelayForeignKcpSubtitle,
        ),
        EditorSwitch(
          icon: Icons.bolt_rounded,
          controller: controller,
          name: 'flags.disableRelayQuic',
          read: (n) => n.flags.disableRelayQuic,
          write: (n, value) => n.flags.disableRelayQuic = value,
          title: l10n.advancedDisableRelayQuic,
          subtitle: l10n.advancedDisableRelayQuicSubtitle,
        ),
        EditorSwitch(
          icon: Icons.language_rounded,
          controller: controller,
          name: 'flags.enableRelayForeignNetworkQuic',
          read: (n) => n.flags.enableRelayForeignNetworkQuic,
          write: (n, value) => n.flags.enableRelayForeignNetworkQuic = value,
          title: l10n.advancedRelayForeignQuic,
          subtitle: l10n.advancedRelayForeignQuicSubtitle,
        ),
        EditorSwitch(
          icon: Icons.podcasts_rounded,
          controller: controller,
          name: 'flags.enableUdpBroadcastRelay',
          read: (n) => n.flags.enableUdpBroadcastRelay,
          write: (n, value) => n.flags.enableUdpBroadcastRelay = value,
          title: l10n.advancedUdpBroadcastRelay,
          subtitle: l10n.advancedUdpBroadcastRelaySubtitle,
        ),
        EditorTextField(
          label: l10n.advancedForeignRelayLimit,
          helper: l10n.advancedForeignRelayLimitHelper,
          initialValue: network.flags.foreignRelayBpsLimit?.toString() ?? '',
          keyboardType: TextInputType.number,
          validator: (value) => validateOptionalIntRange(
            value,
            l10n.advancedForeignRelayLimit,
            1,
            0x7fffffff,
          ),
          onSaved: (value) => controller.update(
            (n) => n.flags.foreignRelayBpsLimit = value.trim().isEmpty
                ? null
                : int.parse(value.trim()),
          ),
        ),
      ],
    );
  }
}

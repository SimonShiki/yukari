import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';
import 'validated_text_field.dart';

/// What this node forwards for other peers and networks.
class RelaySection extends StatelessWidget {
  const RelaySection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedRelay,
      icon: Icons.swap_calls,
      description: l10n.advancedRelayDescription,
      collapsible: true,
      children: [
        FieldSegment(
          child: ValidatedTextField(
            initialValue: controller.network
                .peek()!
                .flags
                .relayNetworkWhitelist,
            decoration: InputDecoration(
              labelText: l10n.advancedRelayWhitelist,
              hintText: '*',
              helperText: l10n.advancedRelayWhitelistHelper,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onValid: (v) => controller.update(
              (n) => n.flags.relayNetworkWhitelist = v.trim(),
            ),
          ),
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedRelayAllPeerRpc,
          subtitle: l10n.advancedRelayAllPeerRpcSubtitle,
          read: (f) => f.relayAllPeerRpc,
          write: (f, v) => f.relayAllPeerRpc = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableRelayData,
          subtitle: l10n.advancedDisableRelayDataSubtitle,
          read: (f) => f.disableRelayData,
          write: (f, v) => f.disableRelayData = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedPreferPeerRelay,
          subtitle: l10n.advancedPreferPeerRelaySubtitle,
          read: (f) => f.preferPeerRelay,
          write: (f, v) => f.preferPeerRelay = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableRelayKcp,
          subtitle: l10n.advancedDisableRelayKcpSubtitle,
          read: (f) => f.disableRelayKcp,
          write: (f, v) => f.disableRelayKcp = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedRelayForeignKcp,
          subtitle: l10n.advancedRelayForeignKcpSubtitle,
          read: (f) => f.enableRelayForeignNetworkKcp,
          write: (f, v) => f.enableRelayForeignNetworkKcp = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableRelayQuic,
          subtitle: l10n.advancedDisableRelayQuicSubtitle,
          read: (f) => f.disableRelayQuic,
          write: (f, v) => f.disableRelayQuic = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedRelayForeignQuic,
          subtitle: l10n.advancedRelayForeignQuicSubtitle,
          read: (f) => f.enableRelayForeignNetworkQuic,
          write: (f, v) => f.enableRelayForeignNetworkQuic = v,
        ),
        OptionalIntField(
          label: l10n.advancedForeignRelayLimit,
          helper: l10n.advancedForeignRelayLimitHelper,
          initial: controller.network.peek()!.flags.foreignRelayBpsLimit,
          min: 1,
          max: 0x7fffffffffffffff,
          onValid: (v) =>
              controller.update((n) => n.flags.foreignRelayBpsLimit = v),
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedUdpBroadcastRelay,
          subtitle: l10n.advancedUdpBroadcastRelaySubtitle,
          read: (f) => f.enableUdpBroadcastRelay,
          write: (f, v) => f.enableUdpBroadcastRelay = v,
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// P2P & NAT Traversal: direct connections and hole punching.
class AdvancedP2pSection extends StatelessWidget {
  const AdvancedP2pSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedP2p,
      icon: Icons.hub,
      description: l10n.advancedP2pDescription,
      collapsible: true,
      children: [
        EditorSwitch(
          icon: Icons.device_hub_rounded,
          controller: controller,
          name: 'flags.disableP2p',
          read: (n) => n.flags.disableP2p,
          write: (n, value) => n.flags.disableP2p = value,
          title: l10n.advancedDisableP2p,
          subtitle: l10n.advancedDisableP2pSubtitle,
        ),
        EditorSwitch(
          icon: Icons.hub_outlined,
          controller: controller,
          name: 'flags.p2pOnly',
          read: (n) => n.flags.p2pOnly,
          write: (n, value) => n.flags.p2pOnly = value,
          title: l10n.advancedP2pOnly,
          subtitle: l10n.advancedP2pOnlySubtitle,
        ),
        EditorSwitch(
          icon: Icons.snooze_rounded,
          controller: controller,
          name: 'flags.lazyP2p',
          read: (n) => n.flags.lazyP2p,
          write: (n, value) => n.flags.lazyP2p = value,
          title: l10n.advancedLazyP2p,
          subtitle: l10n.advancedLazyP2pSubtitle,
        ),
        EditorSwitch(
          icon: Icons.alt_route_rounded,
          controller: controller,
          name: 'flags.needP2p',
          read: (n) => n.flags.needP2p,
          write: (n, value) => n.flags.needP2p = value,
          title: l10n.advancedNeedP2p,
          subtitle: l10n.advancedNeedP2pSubtitle,
        ),
        EditorSwitch(
          icon: Icons.settings_ethernet_rounded,
          controller: controller,
          name: 'flags.disableUdpHolePunching',
          read: (n) => n.flags.disableUdpHolePunching,
          write: (n, value) => n.flags.disableUdpHolePunching = value,
          title: l10n.advancedDisableUdpHolePunching,
          subtitle: l10n.advancedDisableUdpHolePunchingSubtitle,
        ),
        EditorSwitch(
          icon: Icons.cable_rounded,
          controller: controller,
          name: 'flags.disableTcpHolePunching',
          read: (n) => n.flags.disableTcpHolePunching,
          write: (n, value) => n.flags.disableTcpHolePunching = value,
          title: l10n.advancedDisableTcpHolePunching,
          subtitle: l10n.advancedDisableTcpHolePunchingSubtitle,
        ),
        EditorSwitch(
          icon: Icons.call_split_rounded,
          controller: controller,
          name: 'flags.disableSymmetricHolePunching',
          read: (n) => n.flags.disableSymmetricHolePunching,
          write: (n, value) => n.flags.disableSymmetricHolePunching = value,
          title: l10n.advancedDisableSymmetricHolePunching,
          subtitle: l10n.advancedDisableSymmetricHolePunchingSubtitle,
        ),
        EditorSwitch(
          icon: Icons.router_outlined,
          controller: controller,
          name: 'flags.disableUpnp',
          read: (n) => n.flags.disableUpnp,
          write: (n, value) => n.flags.disableUpnp = value,
          title: l10n.advancedDisableUpnp,
          subtitle: l10n.advancedDisableUpnpSubtitle,
        ),
        EditorSwitch(
          icon: Icons.link_rounded,
          controller: controller,
          name: 'flags.bindDevice',
          read: (n) => n.flags.bindDevice,
          write: (n, value) => n.flags.bindDevice = value,
          title: l10n.advancedBindDevice,
          subtitle: l10n.advancedBindDeviceSubtitle,
        ),
      ],
    );
  }
}

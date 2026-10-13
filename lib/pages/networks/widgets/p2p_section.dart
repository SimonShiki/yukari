import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';

/// How this node connects directly to peers.
class P2pSection extends StatelessWidget {
  const P2pSection({super.key, required this.controller});

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
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableP2p,
          subtitle: l10n.advancedDisableP2pSubtitle,
          read: (f) => f.disableP2p,
          write: (f, v) => f.disableP2p = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedP2pOnly,
          subtitle: l10n.advancedP2pOnlySubtitle,
          read: (f) => f.p2pOnly,
          write: (f, v) => f.p2pOnly = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedLazyP2p,
          subtitle: l10n.advancedLazyP2pSubtitle,
          read: (f) => f.lazyP2p,
          write: (f, v) => f.lazyP2p = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedNeedP2p,
          subtitle: l10n.advancedNeedP2pSubtitle,
          read: (f) => f.needP2p,
          write: (f, v) => f.needP2p = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableUdpHolePunching,
          subtitle: l10n.advancedDisableUdpHolePunchingSubtitle,
          read: (f) => f.disableUdpHolePunching,
          write: (f, v) => f.disableUdpHolePunching = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableTcpHolePunching,
          subtitle: l10n.advancedDisableTcpHolePunchingSubtitle,
          read: (f) => f.disableTcpHolePunching,
          write: (f, v) => f.disableTcpHolePunching = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableSymmetricHolePunching,
          subtitle: l10n.advancedDisableSymmetricHolePunchingSubtitle,
          read: (f) => f.disableSymmetricHolePunching,
          write: (f, v) => f.disableSymmetricHolePunching = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedDisableUpnp,
          subtitle: l10n.advancedDisableUpnpSubtitle,
          read: (f) => f.disableUpnp,
          write: (f, v) => f.disableUpnp = v,
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedBindDevice,
          subtitle: l10n.advancedBindDeviceSubtitle,
          read: (f) => f.bindDevice,
          write: (f, v) => f.bindDevice = v,
        ),
      ],
    );
  }
}

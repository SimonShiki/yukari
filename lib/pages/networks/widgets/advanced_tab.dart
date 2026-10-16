import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/section_list.dart';
import 'advanced_access_section.dart';
import 'advanced_flags_section.dart';
import 'advanced_p2p_section.dart';
import 'advanced_public_ipv6_section.dart';
import 'advanced_relay_section.dart';
import 'advanced_routing_section.dart';
import 'advanced_security_section.dart';
import 'advanced_services_section.dart';
import 'advanced_stun_section.dart';
import 'advanced_tuning_section.dart';
import 'advanced_vpn_portal_section.dart';
import 'listener_section.dart';

/// The Advanced tab: every section the editor offers, in order, with the first
/// one expanded and the rest collapsed.
class EditorAdvancedTab extends StatelessWidget {
  const EditorAdvancedTab({
    super.key,
    required this.controller,
    required this.formKey,
  });

  final NetworkEditorController controller;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SectionList(
        children: [
          AdvancedServicesSection(controller: controller),
          EditorListenerSection(
            controller: controller,
            list: ListenerList.local,
            title: l10n.networkListeners,
            description: l10n.networkListenersDescription,
            collapsible: false,
          ),
          AdvancedRoutingSection(controller: controller),
          AdvancedFlagsSection(controller: controller),
          AdvancedSecuritySection(controller: controller),
          AdvancedP2pSection(controller: controller),
          AdvancedRelaySection(controller: controller),
          AdvancedAccessSection(controller: controller),
          EditorListenerSection(
            controller: controller,
            list: ListenerList.mapped,
            title: l10n.advancedMappedListeners,
            description: l10n.advancedMappedListenersDescription,
          ),
          AdvancedStunSection(controller: controller),
          AdvancedPublicIpv6Section(controller: controller),
          AdvancedVpnPortalSection(controller: controller),
          AdvancedTuningSection(controller: controller),
        ],
      ),
    );
  }
}

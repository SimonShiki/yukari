import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Public IPv6: taking an address from a peer, sharing a subnet, and the
/// subnet itself.
class AdvancedPublicIpv6Section extends StatelessWidget {
  const AdvancedPublicIpv6Section({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedPublicIpv6,
      icon: Icons.public,
      description: l10n.advancedPublicIpv6Description,
      collapsible: true,
      children: [
        EditorSwitch(
          icon: Icons.travel_explore_rounded,
          controller: controller,
          name: 'ipv6PublicAddressAuto',
          read: (n) => n.ipv6PublicAddressAuto,
          write: (n, value) => n.ipv6PublicAddressAuto = value,
          title: l10n.advancedAutoPublicIpv6,
          subtitle: l10n.advancedAutoPublicIpv6Subtitle,
        ),
        EditorSwitch(
          icon: Icons.cloud_upload_outlined,
          controller: controller,
          name: 'ipv6PublicAddressProvider',
          read: (n) => n.ipv6PublicAddressProvider,
          write: (n, value) => n.ipv6PublicAddressProvider = value,
          title: l10n.advancedSharePublicIpv6,
          subtitle: l10n.advancedSharePublicIpv6Subtitle,
        ),
        EditorTextField(
          label: l10n.advancedSharedSubnet,
          hint: '2001:db8::/64',
          helper: l10n.advancedSharedSubnetHelper,
          initialValue: network.ipv6PublicAddressPrefix ?? '',
          validator: (value) => validateCidr(value, InternetAddressType.IPv6),
          onSaved: (value) => controller.update(
            (n) => n.ipv6PublicAddressPrefix = value.isEmpty ? null : value,
          ),
        ),
      ],
    );
  }
}

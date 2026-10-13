import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';
import 'validated_text_field.dart';

/// Sharing a public IPv6 subnet between peers.
class PublicIpv6Section extends StatelessWidget {
  const PublicIpv6Section({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedPublicIpv6,
      icon: Icons.public,
      description: l10n.advancedPublicIpv6Description,
      collapsible: true,
      children: [
        NetworkSwitch(
          controller: controller,
          title: l10n.advancedAutoPublicIpv6,
          subtitle: l10n.advancedAutoPublicIpv6Subtitle,
          read: (n) => n.ipv6PublicAddressAuto,
          write: (n, v) => n.ipv6PublicAddressAuto = v,
        ),
        NetworkSwitch(
          controller: controller,
          title: l10n.advancedSharePublicIpv6,
          subtitle: l10n.advancedSharePublicIpv6Subtitle,
          read: (n) => n.ipv6PublicAddressProvider,
          write: (n, v) => n.ipv6PublicAddressProvider = v,
        ),
        FieldSegment(
          child: ValidatedTextField(
            initialValue: controller.network.peek()!.ipv6PublicAddressPrefix,
            decoration: InputDecoration(
              labelText: l10n.advancedSharedSubnet,
              hintText: '2001:db8::/64',
              helperText: l10n.advancedSharedSubnetHelper,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => validateCidr(v, InternetAddressType.IPv6),
            onValid: (v) => controller.update(
              (n) => n.ipv6PublicAddressPrefix = v.isEmpty ? null : v,
            ),
          ),
        ),
      ],
    );
  }
}

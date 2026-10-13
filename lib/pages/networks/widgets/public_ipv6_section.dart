import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../utils/validator.dart';
import 'form_segments.dart';
import 'network_fields.dart';
import 'network_form_section.dart';
import 'validated_text_field.dart';

/// Sharing a public IPv6 subnet between peers.
class PublicIpv6Section extends StatelessWidget {
  const PublicIpv6Section({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Public IPv6',
    icon: Icons.public,
    description: 'Give peers public IPv6 addresses from a shared subnet',
    collapsible: true,
    children: [
      NetworkSwitch(
        controller: controller,
        title: 'Auto Public IPv6',
        subtitle: 'Get a public IPv6 address from a peer sharing its subnet',
        read: (n) => n.ipv6PublicAddressAuto,
        write: (n, v) => n.ipv6PublicAddressAuto = v,
      ),
      NetworkSwitch(
        controller: controller,
        title: 'Share Public IPv6 Subnet',
        subtitle: 'Linux only: hand out addresses from this node’s subnet',
        read: (n) => n.ipv6PublicAddressProvider,
        write: (n, v) => n.ipv6PublicAddressProvider = v,
      ),
      FieldSegment(
        child: ValidatedTextField(
          initialValue: controller.network.peek()!.ipv6PublicAddressPrefix,
          decoration: const InputDecoration(
            labelText: 'Shared Subnet (Optional)',
            hintText: '2001:db8::/64',
            helperText: 'Subnet to share. Leave empty to detect it from routes',
            border: OutlineInputBorder(),
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

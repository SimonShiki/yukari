import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// DHCP and the two addresses it assigns, or the ones typed in.
class EditorIpSection extends StatelessWidget {
  const EditorIpSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.networkIpConfiguration,
      icon: Icons.network_check,
      children: [
        EditorSwitch(
          controller: controller,
          name: 'dhcp',
          read: (n) => n.dhcp,
          write: (n, value) => n.dhcp = value,
          title: l10n.networkDhcp,
          subtitle: l10n.networkDhcpDescription,
        ),
        SignalBuilder(
          builder: (context) => EditorTextField(
            label: l10n.networkIpv4,
            hint: '10.144.144.1/24',
            helper: l10n.networkIpv4Helper,
            initialValue: network.ipv4 ?? '',
            enabled: !controller.select('dhcp', (n) => n.dhcp, true).value,
            textInputAction: TextInputAction.next,
            validator: (value) => validateCidr(value, InternetAddressType.IPv4),
            onSaved: (value) =>
                controller.update((n) => n.ipv4 = value.isEmpty ? null : value),
          ),
        ),
        EditorTextField(
          label: l10n.networkIpv6,
          hint: 'fd00::1/64',
          helper: l10n.networkIpv6Helper,
          initialValue: network.ipv6 ?? '',
          textInputAction: TextInputAction.next,
          validator: (value) => validateCidr(value, InternetAddressType.IPv6),
          onSaved: (value) =>
              controller.update((n) => n.ipv6 = value.isEmpty ? null : value),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Network Services: the SOCKS5 proxy, the TUN device and the namespace.
class AdvancedServicesSection extends StatelessWidget {
  const AdvancedServicesSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedNetworkServices,
      icon: Icons.dns,
      description: l10n.advancedNetworkServicesDescription,
      children: [
        EditorTextField(
          label: l10n.advancedSocks5Proxy,
          hint: 'socks5://host:port',
          helper: l10n.advancedSocks5ProxyHelper,
          initialValue: network.socks5Proxy?.toString() ?? '',
          keyboardType: TextInputType.url,
          validator: validateSocks5Proxy,
          onSaved: (value) => controller.update(
            (n) => n.socks5Proxy = value.isEmpty ? null : Uri.parse(value),
          ),
        ),
        EditorTextField(
          label: l10n.advancedTunDeviceName,
          helper: l10n.advancedTunDeviceNameHelper,
          initialValue: network.flags.deviceName,
          onSaved: (value) =>
              controller.update((n) => n.flags.deviceName = value.trim()),
        ),
        EditorTextField(
          label: l10n.advancedNetNamespace,
          helper: l10n.advancedNetNamespaceHelper,
          initialValue: network.netNamespace ?? '',
          onSaved: (value) =>
              controller.update((n) => n.netNamespace = value.isEmpty ? null : value),
        ),
        EditorSwitch(
          icon: Icons.desktop_access_disabled_rounded,
          controller: controller,
          name: 'flags.noTun',
          read: (n) => n.flags.noTun,
          write: (n, value) => n.flags.noTun = value,
          title: l10n.advancedNoTun,
          subtitle: l10n.advancedNoTunSubtitle,
        ),
      ],
    );
  }
}

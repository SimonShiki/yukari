import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// The network's own identity: its name, its hostname and its secret.
class EditorIdentitySection extends StatelessWidget {
  const EditorIdentitySection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.networkIdentity,
      icon: Icons.fingerprint,
      children: [
        EditorTextField(
          label: l10n.networkName,
          helper: l10n.networkNameHelper,
          initialValue: network.networkName,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              validateNetworkName(value, controller.otherNames),
          onSaved: (value) =>
              controller.update((n) => n.networkName = value.trim()),
        ),
        EditorTextField(
          label: l10n.networkHostname,
          helper: l10n.networkHostnameHelper,
          initialValue: network.hostname ?? '',
          maxLength: 32,
          textInputAction: TextInputAction.next,
          validator: validateHostname,
          onSaved: (value) => controller.update((n) {
            final host = value.trim();
            n.hostname = host.isEmpty ? null : host;
          }),
        ),
        SignalBuilder(
          builder: (context) => EditorTextField(
            label: l10n.networkSecret,
            helper: l10n.networkSecretHelper,
            initialValue: network.networkSecret ?? '',
            value: controller
                .select('secret', (n) => n.networkSecret ?? '', '')
                .value,
            showTooltip: l10n.networkShowSecret,
            hideTooltip: l10n.networkHideSecret,
            generateTooltip: l10n.networkGenerateSecret,
            onGenerate: controller.generateSecret,
            onSaved: (value) => controller.update(
              (n) => n.networkSecret = value.isEmpty ? null : value,
            ),
          ),
        ),
      ],
    );
  }
}

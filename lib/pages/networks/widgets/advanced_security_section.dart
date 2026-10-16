import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../controllers/network_editor_security.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/snackbar/app_snackbar.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'editor_fields.dart';

/// Security: secure mode, and the key pair it authenticates with.
class AdvancedSecuritySection extends StatelessWidget {
  const AdvancedSecuritySection({super.key, required this.controller});

  final NetworkEditorController controller;

  /// Copies the derived public key, so it can be pasted on a peer.
  Future<void> _copyPublicKey(BuildContext context) async {
    final publicKey = controller.working.value?.secureMode?.localPublicKey;
    if (publicKey == null || publicKey.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: publicKey));
    if (!context.mounted) return;
    showAppSnackBar(context, context.l10n.advancedPublicKeyCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Field seeds are read once, outside any SignalBuilder.
    final network = controller.working.value!;
    return SignalBuilder(
      builder: (context) {
        final enabled = controller
            .select(
              'secureMode.enabled',
              (n) => n.secureMode?.enabled ?? false,
              false,
            )
            .value;
        return FormSection(
          title: l10n.advancedSecurity,
          icon: Icons.security,
          description: l10n.advancedSecurityDescription,
          children: [
            SwitchSegment(
              title: l10n.advancedSecureMode,
              subtitle: l10n.advancedSecureModeSubtitle,
              value: enabled,
              onChanged: controller.setSecureMode,
            ),
            if (enabled)
              SignalBuilder(
                builder: (context) => EditorTextField(
                  key: const ValueKey('privateKey'),
                  label: l10n.advancedPrivateKey,
                  helper: l10n.advancedPrivateKeyHelper,
                  initialValue: network.secureMode?.localPrivateKey ?? '',
                  value: controller
                      .select(
                        'secureMode.privateKey',
                        (n) => n.secureMode?.localPrivateKey ?? '',
                        '',
                      )
                      .value,
                  showTooltip: l10n.advancedShowPrivateKey,
                  hideTooltip: l10n.advancedHidePrivateKey,
                  generateTooltip: l10n.advancedGenerateKeyPair,
                  onGenerate: controller.generateKeyPair,
                  validator: validatePrivateKey,
                  onSaved: controller.setPrivateKey,
                ),
              ),
            if (enabled)
              SignalBuilder(
                builder: (context) => EditorTextField(
                  key: const ValueKey('publicKey'),
                  label: l10n.advancedPublicKey,
                  helper: l10n.advancedPublicKeyHelper,
                  initialValue: network.secureMode?.localPublicKey ?? '',
                  value: controller
                      .select(
                        'secureMode.publicKey',
                        (n) => n.secureMode?.localPublicKey ?? '',
                        '',
                      )
                      .value,
                  showTooltip: l10n.advancedShowPublicKey,
                  hideTooltip: l10n.advancedHidePublicKey,
                  readOnly: true,
                  copyTooltip: l10n.advancedCopyPublicKey,
                  onCopy: () => _copyPublicKey(context),
                  onSaved: (_) {},
                ),
              ),
          ],
        );
      },
    );
  }
}

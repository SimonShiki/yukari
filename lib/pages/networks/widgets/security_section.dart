import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network_components.dart';
import '../../../utils/crypto_utils.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/form_section/form_section.dart';
import 'validated_text_field.dart';

/// Secure mode and the node key pair it authenticates peers with.
class SecuritySection extends StatefulWidget {
  const SecuritySection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> {
  final _privateKeyVisible = signal(false);
  final _publicKeyVisible = signal(false);
  late final _privateKeyController = TextEditingController(
    text: _secureMode?.localPrivateKey,
  );
  late final _publicKeyController = TextEditingController(
    text: _secureMode?.localPublicKey,
  );

  SecureMode? get _secureMode => widget.controller.network.value!.secureMode;

  bool get _enabled => _secureMode?.enabled ?? false;

  @override
  void dispose() {
    _privateKeyVisible.dispose();
    _publicKeyVisible.dispose();
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  /// Turning secure mode off keeps the key pair for later, like the VPN portal.
  Future<void> _setEnabled(bool enabled) async {
    if (!enabled) {
      await widget.controller.update((n) {
        if (n.secureMode case final mode?) mode.enabled = false;
      });
      return;
    }
    await widget.controller.update(
      (n) => (n.secureMode ??= SecureMode()).enabled = true,
    );
    // Without a key pair secure mode cannot authenticate anyone.
    var privateKey = _privateKeyController.text;
    if (privateKey.isEmpty) {
      privateKey = generatePrivateKey();
      _privateKeyController.text = privateKey;
    }
    if (_secureMode?.localPrivateKey != privateKey) {
      await _setPrivateKey(privateKey);
    }
  }

  Future<void> _setPrivateKey(String privateKey) async {
    if (privateKey.isEmpty) {
      _publicKeyController.clear();
      // Nothing to authenticate with, so secure mode turns itself off.
      await widget.controller.update((n) {
        final mode = n.secureMode;
        if (mode == null) return;
        mode.enabled = false;
        mode.localPrivateKey = null;
        mode.localPublicKey = null;
      });
      return;
    }
    final publicKey = await derivePublicKey(privateKey);
    // Drop the result if a newer key was entered while deriving.
    if (!mounted || _privateKeyController.text != privateKey) return;
    _publicKeyController.text = publicKey;
    await widget.controller.update((n) {
      final mode = n.secureMode ??= SecureMode();
      mode.localPrivateKey = privateKey;
      mode.localPublicKey = publicKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) => FormSection(
        title: l10n.advancedSecurity,
        icon: Icons.security,
        description: l10n.advancedSecurityDescription,
        children: [
          SwitchSegment(
            title: l10n.advancedSecureMode,
            subtitle: l10n.advancedSecureModeSubtitle,
            value: _enabled,
            onChanged: _setEnabled,
          ),
          // The key pair only applies while secure mode is on.
          if (_enabled) ...[
            FieldSegment(
              child: SignalBuilder(
                builder: (context) => ValidatedTextField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    labelText: l10n.advancedPrivateKey,
                    helperText: l10n.advancedPrivateKeyHelper,
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _privateKeyVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip: _privateKeyVisible.value
                              ? l10n.advancedHidePrivateKey
                              : l10n.advancedShowPrivateKey,
                          onPressed: () => _privateKeyVisible.value =
                              !_privateKeyVisible.value,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: l10n.advancedGenerateKeyPair,
                          onPressed: () {
                            _privateKeyController.text = generatePrivateKey();
                            _setPrivateKey(_privateKeyController.text);
                          },
                        ),
                      ],
                    ),
                  ),
                  obscureText: !_privateKeyVisible.value,
                  validator: validatePrivateKey,
                  onValid: _setPrivateKey,
                ),
              ),
            ),
            FieldSegment(
              child: SignalBuilder(
                builder: (context) => TextField(
                  controller: _publicKeyController,
                  decoration: InputDecoration(
                    labelText: l10n.advancedPublicKey,
                    helperText: l10n.advancedPublicKeyHelper,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _publicKeyVisible.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _publicKeyVisible.value
                          ? l10n.advancedHidePublicKey
                          : l10n.advancedShowPublicKey,
                      onPressed: () =>
                          _publicKeyVisible.value = !_publicKeyVisible.value,
                    ),
                  ),
                  obscureText: !_publicKeyVisible.value,
                  readOnly: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

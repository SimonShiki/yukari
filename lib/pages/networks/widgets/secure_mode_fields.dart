import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network_components.dart';
import '../../../utils/crypto_utils.dart';
import '../../../utils/validator.dart';
import 'form_segments.dart';
import 'network_form_section.dart';
import 'validated_text_field.dart';

/// Secure mode key pair; the public key is derived from the private key.
class SecureModeFields extends StatefulWidget {
  const SecureModeFields({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  State<SecureModeFields> createState() => _SecureModeFieldsState();
}

class _SecureModeFieldsState extends State<SecureModeFields> {
  final _privateKeyVisible = signal(false);
  final _publicKeyVisible = signal(false);
  late final _secureMode = widget.controller.network.peek()!.secureMode;
  late final _privateKeyController = TextEditingController(
    text: _secureMode?.localPrivateKey,
  );
  late final _publicKeyController = TextEditingController(
    text: _secureMode?.localPublicKey,
  );

  @override
  void dispose() {
    _privateKeyVisible.dispose();
    _publicKeyVisible.dispose();
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  Future<void> _setPrivateKey(String privateKey) async {
    if (privateKey.isEmpty) {
      _publicKeyController.clear();
      await widget.controller.update((n) => n.secureMode = null);
      return;
    }
    final publicKey = await derivePublicKey(privateKey);
    // Drop the result if a newer key was entered while deriving.
    if (!mounted || _privateKeyController.text != privateKey) return;
    _publicKeyController.text = publicKey;
    await widget.controller.update(
      (n) => n.secureMode = SecureMode(
        localPrivateKey: privateKey,
        localPublicKey: publicKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Secure Mode Keys',
    icon: Icons.key,
    description: 'Configure cryptographic keys for secure mode',
    children: [
      FieldSegment(
        child: SignalBuilder(
          builder: (context) => ValidatedTextField(
            controller: _privateKeyController,
            decoration: InputDecoration(
              labelText: 'Node Private Key (Base64)',
              helperText: 'Ed25519 private key for authentication',
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
                        ? 'Hide private key'
                        : 'Show private key',
                    onPressed: () =>
                        _privateKeyVisible.value = !_privateKeyVisible.value,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Generate new key pair',
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
              labelText: 'Node Public Key (Base64)',
              helperText: 'Derived from private key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _publicKeyVisible.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                tooltip: _publicKeyVisible.value
                    ? 'Hide public key'
                    : 'Show public key',
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
  );
}

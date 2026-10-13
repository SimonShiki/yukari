import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network_flags.dart';
import '../../../models/node.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';
import 'validated_text_field.dart';

/// Protocol, cipher and runtime details few networks need to change.
class TuningSection extends StatelessWidget {
  const TuningSection({super.key, required this.controller});

  final NetworkEditorController controller;

  NetworkFlags get _flags => controller.network.peek()!.flags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedTuning,
      icon: Icons.tune,
      description: l10n.advancedTuningDescription,
      collapsible: true,
      children: [
        NetworkChoice<NodeProtocol>(
          controller: controller,
          label: l10n.advancedDefaultProtocol,
          helper: l10n.advancedDefaultProtocolHelper,
          options: {
            for (final p in NodeProtocol.values) p: p.name.toUpperCase(),
          },
          read: (n) => n.flags.defaultProtocol,
          write: (n, v) => n.flags.defaultProtocol = v,
        ),
        NetworkChoice<EncryptionAlgorithm>(
          controller: controller,
          label: l10n.advancedEncryptionAlgorithm,
          helper: l10n.advancedEncryptionAlgorithmHelper,
          options: {
            EncryptionAlgorithm.aesGcm: 'AES-128-GCM',
            EncryptionAlgorithm.aes256Gcm: 'AES-256-GCM',
            EncryptionAlgorithm.chacha20: 'ChaCha20-Poly1305',
            EncryptionAlgorithm.xor: l10n.advancedXorInsecure,
          },
          read: (n) => n.flags.encryptionAlgorithm,
          write: (n, v) => n.flags.encryptionAlgorithm = v,
        ),
        NetworkChoice<CompressionAlgorithm>(
          controller: controller,
          label: l10n.advancedCompression,
          helper: l10n.advancedCompressionHelper,
          options: {
            CompressionAlgorithm.none: l10n.advancedCompressionNone,
            CompressionAlgorithm.zstd: 'Zstandard',
          },
          read: (n) => n.flags.compressionAlgorithm,
          write: (n, v) => n.flags.compressionAlgorithm = v,
        ),
        FieldSegment(
          child: ValidatedTextField(
            initialValue: _flags.multiThreadCount.toString(),
            decoration: InputDecoration(
              labelText: l10n.advancedThreadCount,
              helperText: l10n.advancedThreadCountHelper,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (v) =>
                validateIntRange(v, l10n.advancedThreadCountName, 1, 256),
            onValid: (v) => controller.update(
              (n) => n.flags.multiThreadCount = int.parse(v.trim()),
            ),
          ),
        ),
        OptionalIntField(
          label: l10n.advancedReceiveLimit,
          helper: l10n.advancedReceiveLimitHelper,
          initial: _flags.instanceReceiveBpsLimit,
          min: 1,
          max: 0x7fffffffffffffff,
          onValid: (v) =>
              controller.update((n) => n.flags.instanceReceiveBpsLimit = v),
        ),
        FlagSwitch(
          controller: controller,
          title: l10n.advancedSmoltcp,
          subtitle: l10n.advancedSmoltcpSubtitle,
          read: (f) => f.useSmoltcp,
          write: (f, v) => f.useSmoltcp = v,
        ),
        OptionalIntField(
          label: l10n.advancedSocketMark,
          helper: l10n.advancedSocketMarkHelper,
          initial: _flags.socketMark,
          min: 0,
          max: 0xffffffff,
          onValid: (v) => controller.update((n) => n.flags.socketMark = v),
        ),
      ],
    );
  }
}

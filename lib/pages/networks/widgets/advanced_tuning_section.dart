import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/select_item/select_item.dart';
import 'editor_fields.dart';

/// Tuning: protocols, algorithms and resource limits.
class AdvancedTuningSection extends StatelessWidget {
  const AdvancedTuningSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = controller.working.value!;
    return FormSection(
      title: l10n.advancedTuning,
      icon: Icons.tune,
      description: l10n.advancedTuningDescription,
      collapsible: true,
      children: [
        SignalBuilder(
          builder: (context) => SelectItem<NodeProtocol>(
            icon: Icons.swap_horiz_rounded,
            label: l10n.advancedDefaultProtocol,
            supportingText: l10n.advancedDefaultProtocolHelper,
            value: controller
                .select(
                  'flags.defaultProtocol',
                  (n) => n.flags.defaultProtocol,
                  NodeProtocol.tcp,
                )
                .value,
            options: NodeProtocol.values,
            labelOf: (protocol) => protocol.name.toUpperCase(),
            onSelected: (protocol) => controller.update(
              (n) => n.flags.defaultProtocol = protocol,
            ),
          ),
        ),
        SignalBuilder(
          builder: (context) => SelectItem<EncryptionAlgorithm>(
            icon: Icons.lock_outline_rounded,
            label: l10n.advancedEncryptionAlgorithm,
            supportingText: l10n.advancedEncryptionAlgorithmHelper,
            value: controller
                .select(
                  'flags.encryptionAlgorithm',
                  (n) => n.flags.encryptionAlgorithm,
                  EncryptionAlgorithm.aesGcm,
                )
                .value,
            options: EncryptionAlgorithm.values,
            labelOf: (algorithm) => switch (algorithm) {
              EncryptionAlgorithm.xor => l10n.advancedXorInsecure,
              EncryptionAlgorithm.aesGcm => 'AES-128-GCM',
              EncryptionAlgorithm.aes256Gcm => 'AES-256-GCM',
              EncryptionAlgorithm.chacha20 => 'ChaCha20-Poly1305',
            },
            onSelected: (algorithm) => controller.update(
              (n) => n.flags.encryptionAlgorithm = algorithm,
            ),
          ),
        ),
        SignalBuilder(
          builder: (context) => SelectItem<CompressionAlgorithm>(
            icon: Icons.archive_outlined,
            label: l10n.advancedCompression,
            supportingText: l10n.advancedCompressionHelper,
            value: controller
                .select(
                  'flags.compressionAlgorithm',
                  (n) => n.flags.compressionAlgorithm,
                  CompressionAlgorithm.none,
                )
                .value,
            options: CompressionAlgorithm.values,
            labelOf: (algorithm) => switch (algorithm) {
              CompressionAlgorithm.none => l10n.advancedCompressionNone,
              CompressionAlgorithm.zstd => 'Zstandard',
            },
            onSelected: (algorithm) => controller.update(
              (n) => n.flags.compressionAlgorithm = algorithm,
            ),
          ),
        ),
        EditorTextField(
          label: l10n.advancedThreadCount,
          helper: l10n.advancedThreadCountHelper,
          initialValue: '${network.flags.multiThreadCount}',
          keyboardType: TextInputType.number,
          validator: (value) =>
              validateIntRange(value, l10n.advancedThreadCountName, 1, 256),
          onSaved: (value) => controller.update(
            (n) => n.flags.multiThreadCount = int.parse(value.trim()),
          ),
        ),
        EditorTextField(
          label: l10n.advancedReceiveLimit,
          helper: l10n.advancedReceiveLimitHelper,
          initialValue: network.flags.instanceReceiveBpsLimit?.toString() ?? '',
          keyboardType: TextInputType.number,
          validator: (value) => validateOptionalIntRange(
            value,
            l10n.advancedReceiveLimit,
            1,
            0x7fffffffffffffff,
          ),
          onSaved: (value) => controller.update(
            (n) => n.flags.instanceReceiveBpsLimit = value.trim().isEmpty
                ? null
                : int.parse(value.trim()),
          ),
        ),
        EditorSwitch(
          icon: Icons.settings_ethernet_rounded,
          controller: controller,
          name: 'flags.useSmoltcp',
          read: (n) => n.flags.useSmoltcp,
          write: (n, value) => n.flags.useSmoltcp = value,
          title: l10n.advancedSmoltcp,
          subtitle: l10n.advancedSmoltcpSubtitle,
        ),
        EditorTextField(
          label: l10n.advancedSocketMark,
          helper: l10n.advancedSocketMarkHelper,
          initialValue: network.flags.socketMark?.toString() ?? '',
          keyboardType: TextInputType.number,
          validator: (value) => validateOptionalIntRange(
            value,
            l10n.advancedSocketMark,
            0,
            0xffffffff,
          ),
          onSaved: (value) => controller.update(
            (n) => n.flags.socketMark = value.trim().isEmpty
                ? null
                : int.parse(value.trim()),
          ),
        ),
      ],
    );
  }
}

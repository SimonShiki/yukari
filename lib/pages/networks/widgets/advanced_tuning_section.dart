import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';

import 'package:yukari_core/models/models.dart';

import '../../../widgets/form_section/form_section.dart';
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
        EditorSelect<NodeProtocol>(
          icon: Icons.swap_horiz_rounded,
          label: l10n.advancedDefaultProtocol,
          supportingText: l10n.advancedDefaultProtocolHelper,
          value: controller.select(
            'flags.defaultProtocol',
            (n) => n.flags.defaultProtocol,
            NodeProtocol.tcp,
          ),
          options: NodeProtocol.values,
          labelOf: (protocol) => protocol.name.toUpperCase(),
          onSelected: (protocol) =>
              controller.update((n) => n.flags.defaultProtocol = protocol),
        ),
        EditorSelect<EncryptionAlgorithm>(
          icon: Icons.lock_outline_rounded,
          label: l10n.advancedEncryptionAlgorithm,
          supportingText: l10n.advancedEncryptionAlgorithmHelper,
          value: controller.select(
            'flags.encryptionAlgorithm',
            (n) => n.flags.encryptionAlgorithm,
            EncryptionAlgorithm.aesGcm,
          ),
          options: EncryptionAlgorithm.values,
          labelOf: (algorithm) => switch (algorithm) {
            EncryptionAlgorithm.xor => l10n.advancedXorInsecure,
            EncryptionAlgorithm.aesGcm => 'AES-128-GCM',
            EncryptionAlgorithm.aes256Gcm => 'AES-256-GCM',
            EncryptionAlgorithm.chacha20 => 'ChaCha20-Poly1305',
          },
          onSelected: (algorithm) =>
              controller.update((n) => n.flags.encryptionAlgorithm = algorithm),
        ),
        EditorSelect<CompressionAlgorithm>(
          icon: Icons.archive_outlined,
          label: l10n.advancedCompression,
          supportingText: l10n.advancedCompressionHelper,
          value: controller.select(
            'flags.compressionAlgorithm',
            (n) => n.flags.compressionAlgorithm,
            CompressionAlgorithm.none,
          ),
          options: CompressionAlgorithm.values,
          labelOf: (algorithm) => switch (algorithm) {
            CompressionAlgorithm.none => l10n.advancedCompressionNone,
            CompressionAlgorithm.zstd => 'Zstandard',
            CompressionAlgorithm.lzo => 'LZO',
          },
          onSelected: (algorithm) => controller.update(
            (n) => n.flags.compressionAlgorithm = algorithm,
          ),
        ),
        editorIntField(
          label: l10n.advancedThreadCount,
          helper: l10n.advancedThreadCountHelper,
          initialValue: network.flags.multiThreadCount,
          name: l10n.advancedThreadCountName,
          min: 1,
          max: 256,
          onSaved: (value) =>
              controller.update((n) => n.flags.multiThreadCount = value),
        ),
        editorOptionalIntField(
          label: l10n.advancedReceiveLimit,
          helper: l10n.advancedReceiveLimitHelper,
          initialValue: network.flags.instanceReceiveBpsLimit,
          min: 1,
          max: 0x7fffffffffffffff,
          onSaved: (value) =>
              controller.update((n) => n.flags.instanceReceiveBpsLimit = value),
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
        editorOptionalIntField(
          label: l10n.advancedSocketMark,
          helper: l10n.advancedSocketMarkHelper,
          initialValue: network.flags.socketMark,
          min: 0,
          max: 0xffffffff,
          onSaved: (value) =>
              controller.update((n) => n.flags.socketMark = value),
        ),
      ],
    );
  }
}

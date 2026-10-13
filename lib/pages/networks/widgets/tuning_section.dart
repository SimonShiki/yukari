import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network_flags.dart';
import '../../../models/node.dart';
import '../../../utils/validator.dart';
import 'form_segments.dart';
import 'network_fields.dart';
import 'network_form_section.dart';
import 'validated_text_field.dart';

/// Protocol, cipher and runtime details few networks need to change.
class TuningSection extends StatelessWidget {
  const TuningSection({super.key, required this.controller});

  final NetworkEditorController controller;

  NetworkFlags get _flags => controller.network.peek()!.flags;

  @override
  Widget build(BuildContext context) => NetworkFormSection(
    title: 'Tuning',
    icon: Icons.tune,
    description: 'Protocols, algorithms and resource limits',
    collapsible: true,
    children: [
      NetworkChoice<NodeProtocol>(
        controller: controller,
        label: 'Default Protocol',
        helper: 'Used for peers given without a protocol',
        options: {for (final p in NodeProtocol.values) p: p.name.toUpperCase()},
        read: (n) => n.flags.defaultProtocol,
        write: (n, v) => n.flags.defaultProtocol = v,
      ),
      NetworkChoice<EncryptionAlgorithm>(
        controller: controller,
        label: 'Encryption Algorithm',
        helper: 'Must match on every peer',
        options: const {
          EncryptionAlgorithm.aesGcm: 'AES-128-GCM',
          EncryptionAlgorithm.aes256Gcm: 'AES-256-GCM',
          EncryptionAlgorithm.chacha20: 'ChaCha20-Poly1305',
          EncryptionAlgorithm.xor: 'XOR (insecure)',
        },
        read: (n) => n.flags.encryptionAlgorithm,
        write: (n, v) => n.flags.encryptionAlgorithm = v,
      ),
      NetworkChoice<CompressionAlgorithm>(
        controller: controller,
        label: 'Compression',
        helper: 'Compress traffic sent to peers',
        options: const {
          CompressionAlgorithm.none: 'None',
          CompressionAlgorithm.zstd: 'Zstandard',
        },
        read: (n) => n.flags.compressionAlgorithm,
        write: (n, v) => n.flags.compressionAlgorithm = v,
      ),
      FieldSegment(
        child: ValidatedTextField(
          initialValue: _flags.multiThreadCount.toString(),
          decoration: const InputDecoration(
            labelText: 'Thread Count',
            helperText: 'Worker threads when multi-threading is on',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => validateIntRange(v, 'Thread count', 1, 256),
          onValid: (v) => controller.update(
            (n) => n.flags.multiThreadCount = int.parse(v.trim()),
          ),
        ),
      ),
      OptionalIntField(
        label: 'Receive Limit',
        helper:
            'Bytes per second this node receives in total. Leave empty for no '
            'limit',
        initial: _flags.instanceReceiveBpsLimit,
        min: 1,
        max: 0x7fffffffffffffff,
        onValid: (v) =>
            controller.update((n) => n.flags.instanceReceiveBpsLimit = v),
      ),
      FlagSwitch(
        controller: controller,
        title: 'User-Space Network Stack',
        subtitle:
            'Use smoltcp when system firewalls block subnet or KCP proxying',
        read: (f) => f.useSmoltcp,
        write: (f, v) => f.useSmoltcp = v,
      ),
      OptionalIntField(
        label: 'Socket Mark',
        helper:
            'Linux only: SO_MARK for policy routing of underlay sockets. '
            'Needs CAP_NET_ADMIN',
        initial: _flags.socketMark,
        min: 0,
        max: 0xffffffff,
        onValid: (v) => controller.update((n) => n.flags.socketMark = v),
      ),
    ],
  );
}

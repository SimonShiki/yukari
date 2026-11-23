import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';

import 'package:yukari_core/utils/dns_name.dart';

import 'editor_fields.dart';

/// Network Flags: the protocol and performance switches, Magic DNS and the MTU.
class AdvancedFlagsSection extends StatelessWidget {
  const AdvancedFlagsSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) {
        final network = controller.working.peek()!;
        final magicDns = editorSwitch(
          controller,
          'flags.acceptDns',
          (n) => n.flags.acceptDns,
        ).value;
        final udpFec = editorSwitch(
          controller,
          'flags.enableUdpFec',
          (n) => n.flags.enableUdpFec,
        ).value;
        return FormSection(
          title: l10n.advancedNetworkFlags,
          icon: Icons.flag,
          description: l10n.advancedNetworkFlagsDescription,
          children: [
            EditorSwitch(
              icon: Icons.enhanced_encryption_rounded,
              controller: controller,
              name: 'flags.enableEncryption',
              read: (n) => n.flags.enableEncryption,
              write: (n, value) => n.flags.enableEncryption = value,
              title: l10n.advancedEnableEncryption,
              subtitle: l10n.advancedEnableEncryptionSubtitle,
            ),
            EditorSwitch(
              icon: Icons.lan_outlined,
              controller: controller,
              name: 'flags.enableIpv6',
              read: (n) => n.flags.enableIpv6,
              write: (n, value) => n.flags.enableIpv6 = value,
              title: l10n.advancedEnableIpv6,
              subtitle: l10n.advancedEnableIpv6Subtitle,
            ),
            EditorSwitch(
              icon: Icons.speed_rounded,
              controller: controller,
              name: 'flags.latencyFirst',
              read: (n) => n.flags.latencyFirst,
              write: (n, value) => n.flags.latencyFirst = value,
              title: l10n.advancedLatencyFirst,
              subtitle: l10n.advancedLatencyFirstSubtitle,
            ),
            EditorSwitch(
              icon: Icons.memory_rounded,
              controller: controller,
              name: 'flags.multiThread',
              read: (n) => n.flags.multiThread,
              write: (n, value) => n.flags.multiThread = value,
              title: l10n.advancedMultiThread,
              subtitle: l10n.advancedMultiThreadSubtitle,
            ),
            EditorSwitch(
              icon: Icons.swap_calls_rounded,
              controller: controller,
              name: 'flags.enableKcpProxy',
              read: (n) => n.flags.enableKcpProxy,
              write: (n, value) => n.flags.enableKcpProxy = value,
              title: l10n.advancedKcpProxy,
              subtitle: l10n.advancedKcpProxySubtitle,
            ),
            EditorSwitch(
              icon: Icons.bolt_rounded,
              controller: controller,
              name: 'flags.enableQuicProxy',
              read: (n) => n.flags.enableQuicProxy,
              write: (n, value) => n.flags.enableQuicProxy = value,
              title: l10n.advancedQuicProxy,
              subtitle: l10n.advancedQuicProxySubtitle,
            ),
            EditorSwitch(
              icon: Icons.healing_rounded,
              controller: controller,
              name: 'flags.enableUdpFec',
              read: (n) => n.flags.enableUdpFec,
              write: (n, value) => n.flags.enableUdpFec = value,
              title: l10n.advancedUdpFec,
              subtitle: l10n.advancedUdpFecSubtitle,
            ),
            if (udpFec) ...[
              EditorSwitch(
                key: const ValueKey('enableUdpFecKcp'),
                icon: Icons.swap_calls_rounded,
                controller: controller,
                name: 'flags.enableUdpFecKcp',
                read: (n) => n.flags.enableUdpFecKcp,
                write: (n, value) => n.flags.enableUdpFecKcp = value,
                title: l10n.advancedUdpFecKcp,
                subtitle: l10n.advancedUdpFecKcpSubtitle,
              ),
              EditorSwitch(
                key: const ValueKey('enableUdpFecQuic'),
                icon: Icons.bolt_rounded,
                controller: controller,
                name: 'flags.enableUdpFecQuic',
                read: (n) => n.flags.enableUdpFecQuic,
                write: (n, value) => n.flags.enableUdpFecQuic = value,
                title: l10n.advancedUdpFecQuic,
                subtitle: l10n.advancedUdpFecQuicSubtitle,
              ),
            ],
            EditorSwitch(
              icon: Icons.dns_outlined,
              controller: controller,
              name: 'flags.acceptDns',
              read: (n) => n.flags.acceptDns,
              write: (n, value) => n.flags.acceptDns = value,
              title: l10n.advancedMagicDns,
              subtitle: l10n.advancedMagicDnsSubtitle,
              conflict: (
                name: 'flags.noTun',
                read: (n) => n.flags.noTun,
                subtitle: l10n.advancedMagicDnsNeedsTun,
              ),
            ),
            if (magicDns)
              EditorTextField(
                key: const ValueKey('dnsSuffix'),
                label: l10n.advancedDnsSuffix,
                hint: defaultDnsDomain,
                helper: l10n.advancedDnsSuffixHelper,
                initialValue: network.effectiveDnsDomain,
                validator: validateDnsZone,
                onSaved: controller.setDnsDomain,
              ),
            editorIntField(
              key: const ValueKey('mtu'),
              label: l10n.advancedMtuHelper,
              initialValue: network.flags.mtu,
              name: 'MTU',
              min: 576,
              max: 65535,
              onSaved: (value) => controller.update((n) => n.flags.mtu = value),
            ),
          ],
        );
      },
    );
  }
}

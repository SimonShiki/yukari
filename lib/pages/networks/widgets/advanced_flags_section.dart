import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Network Flags: the protocol and performance switches, Magic DNS and the MTU.
class AdvancedFlagsSection extends StatelessWidget {
  const AdvancedFlagsSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Field seeds are read once, outside any SignalBuilder, so a keystroke
    // elsewhere cannot rebuild this section.
    final network = controller.working.value!;
    return SignalBuilder(
      // Only the DNS suffix row depends on a switch; it carries its own key, so
      // the MTU input below it survives the toggle.
      builder: (context) {
        final magicDns = controller
            .select('flags.acceptDns', (n) => n.flags.acceptDns, false)
            .value;
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
              icon: Icons.dns_outlined,
              controller: controller,
              name: 'flags.acceptDns',
              read: (n) => n.flags.acceptDns,
              write: (n, value) => n.flags.acceptDns = value,
              title: l10n.advancedMagicDns,
              subtitle: l10n.advancedMagicDnsSubtitle,
            ),
            if (magicDns)
              EditorTextField(
                key: const ValueKey('dnsSuffix'),
                label: l10n.advancedDnsSuffix,
                hint: 'et.net.',
                helper: l10n.advancedDnsSuffixHelper,
                initialValue: network.flags.dnsZone,
                validator: validateDnsZone,
                onSaved: (value) =>
                    controller.update((n) => n.flags.dnsZone = value.trim()),
              ),
            EditorTextField(
              key: const ValueKey('mtu'),
              label: l10n.advancedMtuHelper,
              initialValue: '${network.flags.mtu}',
              keyboardType: TextInputType.number,
              validator: (value) => validateIntRange(value, 'MTU', 576, 65535),
              onSaved: (value) => controller.update(
                (n) => n.flags.mtu = int.parse(value.trim()),
              ),
            ),
          ],
        );
      },
    );
  }
}

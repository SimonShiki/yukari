import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network.dart';
import '../../../utils/validator.dart';
import 'access_section.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'listener_list_editor.dart';
import 'network_fields.dart';
import '../../../widgets/form_section/form_section.dart';
import 'network_form_tab.dart';
import 'p2p_section.dart';
import 'public_ipv6_section.dart';
import 'relay_section.dart';
import 'routing_section.dart';
import 'secure_mode_fields.dart';
import 'stun_section.dart';
import 'tuning_section.dart';
import 'validated_text_field.dart';
import 'vpn_portal_section.dart';

/// Common settings first; the rest start collapsed.
class NetworkAdvancedTab extends StatefulWidget {
  const NetworkAdvancedTab({
    super.key,
    required this.formKey,
    required this.controller,
  });

  final GlobalKey<FormState> formKey;
  final NetworkEditorController controller;

  @override
  State<NetworkAdvancedTab> createState() => _NetworkAdvancedTabState();
}

class _NetworkAdvancedTabState extends State<NetworkAdvancedTab>
    with AutomaticKeepAliveClientMixin {
  NetworkEditorController get _editor => widget.controller;
  Network get _network => _editor.network.peek()!;
  late final _magicDns = computed(() => _editor.network.value!.flags.acceptDns);

  // Keeps typed text and validation errors when switching tabs.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _magicDns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;

    return NetworkFormTab(
      formKey: widget.formKey,
      children: [
        FormSection(
          title: l10n.advancedNetworkServices,
          icon: Icons.dns,
          description: l10n.advancedNetworkServicesDescription,
          children: [
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.socks5Proxy?.toString(),
                decoration: InputDecoration(
                  labelText: l10n.advancedSocks5Proxy,
                  hintText: 'socks5://host:port',
                  helperText: l10n.advancedSocks5ProxyHelper,
                  border: const OutlineInputBorder(),
                ),
                validator: validateSocks5Proxy,
                onValid: (v) => _editor.update(
                  (n) => n.socks5Proxy = v.isEmpty ? null : Uri.parse(v),
                ),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.flags.deviceName,
                decoration: InputDecoration(
                  labelText: l10n.advancedTunDeviceName,
                  helperText: l10n.advancedTunDeviceNameHelper,
                  border: const OutlineInputBorder(),
                ),
                onValid: (v) =>
                    _editor.update((n) => n.flags.deviceName = v.trim()),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.netNamespace,
                decoration: InputDecoration(
                  labelText: l10n.advancedNetNamespace,
                  helperText: l10n.advancedNetNamespaceHelper,
                  border: const OutlineInputBorder(),
                ),
                onValid: (v) => _editor.update(
                  (n) => n.netNamespace = v.isEmpty ? null : v,
                ),
              ),
            ),
            FlagSwitch(
              controller: _editor,
              title: l10n.advancedNoTun,
              subtitle: l10n.advancedNoTunSubtitle,
              read: (f) => f.noTun,
              write: (f, v) => f.noTun = v,
            ),
          ],
        ),
        SignalBuilder(
          builder: (context) => ListenerListEditor(
            listeners: _editor.network.value!.listeners,
            onListenersChanged: (list) =>
                _editor.update((n) => n.listeners = list),
          ),
        ),
        RoutingSection(controller: _editor),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rebuilds to show the DNS suffix only while Magic DNS is on.
            SignalBuilder(
              builder: (context) => FormSection(
                title: l10n.advancedNetworkFlags,
                icon: Icons.flag,
                description: l10n.advancedNetworkFlagsDescription,
                children: [
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedEnableEncryption,
                    subtitle: l10n.advancedEnableEncryptionSubtitle,
                    read: (f) => f.enableEncryption,
                    write: (f, v) => f.enableEncryption = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedEnableIpv6,
                    subtitle: l10n.advancedEnableIpv6Subtitle,
                    read: (f) => f.enableIpv6,
                    write: (f, v) => f.enableIpv6 = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedLatencyFirst,
                    subtitle: l10n.advancedLatencyFirstSubtitle,
                    read: (f) => f.latencyFirst,
                    write: (f, v) => f.latencyFirst = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedMultiThread,
                    subtitle: l10n.advancedMultiThreadSubtitle,
                    read: (f) => f.multiThread,
                    write: (f, v) => f.multiThread = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedKcpProxy,
                    subtitle: l10n.advancedKcpProxySubtitle,
                    read: (f) => f.enableKcpProxy,
                    write: (f, v) => f.enableKcpProxy = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedQuicProxy,
                    subtitle: l10n.advancedQuicProxySubtitle,
                    read: (f) => f.enableQuicProxy,
                    write: (f, v) => f.enableQuicProxy = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: l10n.advancedMagicDns,
                    subtitle: l10n.advancedMagicDnsSubtitle,
                    read: (f) => f.acceptDns,
                    write: (f, v) => f.acceptDns = v,
                  ),
                  if (_magicDns.value)
                    FieldSegment(
                      key: const ValueKey('dnsZone'),
                      child: ValidatedTextField(
                        initialValue: _network.flags.dnsZone,
                        decoration: InputDecoration(
                          labelText: l10n.advancedDnsSuffix,
                          hintText: 'et.net.',
                          helperText: l10n.advancedDnsSuffixHelper,
                          border: const OutlineInputBorder(),
                        ),
                        validator: validateDnsZone,
                        onValid: (v) =>
                            _editor.update((n) => n.flags.dnsZone = v.trim()),
                      ),
                    ),
                  FieldSegment(
                    child: ValidatedTextField(
                      initialValue: _network.flags.mtu.toString(),
                      decoration: InputDecoration(
                        labelText: 'MTU',
                        helperText: l10n.advancedMtuHelper,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => validateIntRange(v, 'MTU', 576, 65535),
                      onValid: (v) => _editor.update(
                        (n) => n.flags.mtu = int.parse(v.trim()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Secure mode keys only apply while encryption is enabled.
            SignalBuilder(
              builder: (context) => AnimatedSize(
                duration: Durations.medium4,
                curve: Easing.emphasizedDecelerate,
                alignment: Alignment.topCenter,
                child: _editor.network.value!.flags.enableEncryption
                    ? Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: SecureModeFields(controller: _editor),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
        P2pSection(controller: _editor),
        RelaySection(controller: _editor),
        AccessSection(controller: _editor),
        SignalBuilder(
          builder: (context) => ListenerListEditor(
            title: l10n.advancedMappedListeners,
            description: l10n.advancedMappedListenersDescription,
            collapsible: true,
            listeners: _editor.network.value!.mappedListeners,
            onListenersChanged: (list) =>
                _editor.update((n) => n.mappedListeners = list),
          ),
        ),
        StunSection(controller: _editor),
        PublicIpv6Section(controller: _editor),
        VpnPortalSection(controller: _editor),
        TuningSection(controller: _editor),
      ],
    );
  }
}

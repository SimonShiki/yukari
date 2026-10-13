import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
import '../../../utils/validator.dart';
import 'access_section.dart';
import 'form_segments.dart';
import 'listener_list_editor.dart';
import 'network_fields.dart';
import 'network_form_section.dart';
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

    return NetworkFormTab(
      formKey: widget.formKey,
      children: [
        NetworkFormSection(
          title: 'Network Services',
          icon: Icons.dns,
          description: 'SOCKS5, virtual device and namespace',
          children: [
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.socks5Proxy?.toString(),
                decoration: const InputDecoration(
                  labelText: 'SOCKS5 Proxy (Optional)',
                  hintText: 'socks5://host:port',
                  helperText: 'SOCKS5 proxy address for outbound traffic',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'TUN Device Name (Optional)',
                  helperText: 'Name of the virtual network interface',
                  border: OutlineInputBorder(),
                ),
                onValid: (v) =>
                    _editor.update((n) => n.flags.deviceName = v.trim()),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.netNamespace,
                decoration: const InputDecoration(
                  labelText: 'Network Namespace (Optional)',
                  helperText: 'Linux network namespace name',
                  border: OutlineInputBorder(),
                ),
                onValid: (v) => _editor.update(
                  (n) => n.netNamespace = v.isEmpty ? null : v,
                ),
              ),
            ),
            FlagSwitch(
              controller: _editor,
              title: 'Disable TUN Mode',
              subtitle:
                  'Run without a virtual network device; this node can only '
                  'be reached, and reaches others through SOCKS5',
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
              builder: (context) => NetworkFormSection(
                title: 'Network Flags',
                icon: Icons.flag,
                description: 'Protocol and performance settings',
                children: [
                  FlagSwitch(
                    controller: _editor,
                    title: 'Enable Encryption',
                    subtitle:
                        'Encrypt network traffic; must match on every peer',
                    read: (f) => f.enableEncryption,
                    write: (f, v) => f.enableEncryption = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'Enable IPv6',
                    subtitle: 'Allow IPv6 connections',
                    read: (f) => f.enableIpv6,
                    write: (f, v) => f.enableIpv6 = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'Latency First',
                    subtitle: 'Route by lowest total latency instead of hops',
                    read: (f) => f.latencyFirst,
                    write: (f, v) => f.latencyFirst = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'Multi-Threading',
                    subtitle: 'Use multiple threads for processing',
                    read: (f) => f.multiThread,
                    write: (f, v) => f.multiThread = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'KCP Proxy',
                    subtitle: 'Carry TCP over KCP for lower latency and speed',
                    read: (f) => f.enableKcpProxy,
                    write: (f, v) => f.enableKcpProxy = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'QUIC Proxy',
                    subtitle: 'Carry TCP over QUIC for lower latency and speed',
                    read: (f) => f.enableQuicProxy,
                    write: (f, v) => f.enableQuicProxy = v,
                  ),
                  FlagSwitch(
                    controller: _editor,
                    title: 'Magic DNS',
                    subtitle:
                        'Reach peers by name; changes system DNS settings',
                    read: (f) => f.acceptDns,
                    write: (f, v) => f.acceptDns = v,
                  ),
                  if (_magicDns.value)
                    FieldSegment(
                      key: const ValueKey('dnsZone'),
                      child: ValidatedTextField(
                        initialValue: _network.flags.dnsZone,
                        decoration: const InputDecoration(
                          labelText: 'DNS Suffix',
                          hintText: 'et.net.',
                          helperText: 'Peers are named <hostname>.<suffix>',
                          border: OutlineInputBorder(),
                        ),
                        validator: validateDnsZone,
                        onValid: (v) =>
                            _editor.update((n) => n.flags.dnsZone = v.trim()),
                      ),
                    ),
                  FieldSegment(
                    child: ValidatedTextField(
                      initialValue: _network.flags.mtu.toString(),
                      decoration: const InputDecoration(
                        labelText: 'MTU',
                        helperText: 'Maximum Transmission Unit (576-65535)',
                        border: OutlineInputBorder(),
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
            title: 'Mapped Listeners',
            description: 'Public addresses peers use to reach this node',
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

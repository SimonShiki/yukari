import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
import '../../../models/network_flags.dart';
import '../../../utils/validator.dart';
import 'listener_list_editor.dart';
import 'network_form_section.dart';
import 'secure_mode_fields.dart';
import 'validated_text_field.dart';

class NetworkAdvancedTab extends StatefulWidget {
  const NetworkAdvancedTab({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  State<NetworkAdvancedTab> createState() => _NetworkAdvancedTabState();
}

class _NetworkAdvancedTabState extends State<NetworkAdvancedTab>
    with AutomaticKeepAliveClientMixin {
  NetworkEditorController get _editor => widget.controller;
  Network get _network => _editor.network.peek()!;

  // Keeps typed text and validation errors when switching tabs.
  @override
  bool get wantKeepAlive => true;

  Widget _flagSwitch(
    String title,
    String subtitle,
    bool Function(NetworkFlags flags) read,
    void Function(NetworkFlags flags, bool value) write,
  ) => SignalBuilder(
    builder: (context) => SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: read(_editor.network.value!.flags),
      onChanged: (v) => _editor.update((n) => write(n.flags, v)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Network Services at TOP per user requirement
            NetworkFormSection(
              title: 'Network Services',
              icon: Icons.dns,
              children: [
                Text(
                  'Configure network-level services and routing',
                  style: descriptionStyle,
                ),
                const SizedBox(height: 16),
                ValidatedTextField(
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
                const SizedBox(height: 16),
                ValidatedTextField(
                  initialValue: _network.netNamespace,
                  decoration: const InputDecoration(
                    labelText: 'Network Namespace (Optional)',
                    helperText: 'Linux network namespace name',
                    border: OutlineInputBorder(),
                  ),
                  onValid: (v) =>
                      _editor.update((n) => n.netNamespace = v.isEmpty ? null : v),
                ),
                const SizedBox(height: 16),
                _flagSwitch(
                  'Disable TUN Mode',
                  'Run without TUN/TAP virtual network device',
                  (f) => f.noTun,
                  (f, v) => f.noTun = v,
                ),
              ],
            ),
            const SizedBox(height: 16),
            NetworkFormSection(
              title: 'Listeners',
              icon: Icons.podcasts,
              children: [
                Text(
                  'Local addresses for incoming connections',
                  style: descriptionStyle,
                ),
                const SizedBox(height: 16),
                SignalBuilder(
                  builder: (context) => ListenerListEditor(
                    listeners: _editor.network.value!.listeners,
                    onListenersChanged: (list) =>
                        _editor.update((n) => n.listeners = list),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NetworkFormSection(
              title: 'Network Flags',
              icon: Icons.flag,
              children: [
                Text('Protocol and performance settings', style: descriptionStyle),
                const SizedBox(height: 16),
                _flagSwitch(
                  'Enable Encryption',
                  'Encrypt network traffic',
                  (f) => f.enableEncryption,
                  (f, v) => f.enableEncryption = v,
                ),
                _flagSwitch(
                  'Enable IPv6',
                  'Allow IPv6 connections',
                  (f) => f.enableIpv6,
                  (f, v) => f.enableIpv6 = v,
                ),
                _flagSwitch(
                  'Latency First',
                  'Prioritize low latency over throughput',
                  (f) => f.latencyFirst,
                  (f, v) => f.latencyFirst = v,
                ),
                _flagSwitch(
                  'Multi-Threading',
                  'Use multiple threads for processing',
                  (f) => f.multiThread,
                  (f, v) => f.multiThread = v,
                ),
                const SizedBox(height: 16),
                ValidatedTextField(
                  initialValue: _network.flags.mtu.toString(),
                  decoration: const InputDecoration(
                    labelText: 'MTU',
                    helperText: 'Maximum Transmission Unit (576-65535)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => validateIntRange(v, 'MTU', 576, 65535),
                  onValid: (v) =>
                      _editor.update((n) => n.flags.mtu = int.parse(v.trim())),
                ),
                const SizedBox(height: 16),
                SignalBuilder(
                  builder: (context) =>
                      _editor.network.value!.flags.enableEncryption
                      ? SecureModeFields(controller: _editor)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NetworkFormSection(
              title: 'STUN Servers',
              icon: Icons.cloud_sync,
              children: [
                Text('STUN servers for NAT traversal', style: descriptionStyle),
                const SizedBox(height: 16),
                ValidatedTextField(
                  initialValue: _network.stunServers.join('\n'),
                  decoration: const InputDecoration(
                    labelText: 'STUN Servers',
                    hintText: 'stun.example.com:3478',
                    helperText: 'One server per line',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: validateStunServers,
                  onValid: (v) => _editor.update(
                    (n) => n.stunServers = v
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../models/network_builder.dart';
import '../../../models/network_components.dart';
import '../../../utils/crypto_utils.dart';
import 'network_form_section.dart';
import 'listener_list_editor.dart';

class NetworkAdvancedTab extends SignalStatefulWidget {
  const NetworkAdvancedTab({
    super.key,
    required this.builder,
  });

  final NetworkBuilder builder;

  @override
  State<NetworkAdvancedTab> createState() => _NetworkAdvancedTabState();
}

class _NetworkAdvancedTabState extends State<NetworkAdvancedTab> {
  final privateKeyVisible = signal(false);
  final publicKeyVisible = signal(false);
  late final TextEditingController _socks5ProxyController;
  late final TextEditingController _netNamespaceController;
  late final TextEditingController _mtuController;
  late final TextEditingController _privateKeyController;
  late final TextEditingController _publicKeyController;
  late final TextEditingController _stunServersController;
  late final void Function() _unsubscribe;

  NetworkBuilder get builder => widget.builder;

  @override
  void initState() {
    super.initState();
    _socks5ProxyController = TextEditingController(text: builder.socks5Proxy?.toString() ?? '');
    _netNamespaceController = TextEditingController(text: builder.netNamespace ?? '');
    _mtuController = TextEditingController(text: builder.flags.mtu.toString());
    _privateKeyController = TextEditingController(text: builder.secureMode?.localPrivateKey ?? '');
    _publicKeyController = TextEditingController(text: builder.secureMode?.localPublicKey ?? '');
    _stunServersController = TextEditingController(text: builder.stunServers.join('\n'));

    // Subscribe to builder changes to sync controllers when changed externally
    _unsubscribe = effect(() {
      final socks5Proxy = builder.socks5Proxy?.toString() ?? '';
      if (_socks5ProxyController.text != socks5Proxy) {
        _socks5ProxyController.text = socks5Proxy;
      }
      final netNamespace = builder.netNamespace ?? '';
      if (_netNamespaceController.text != netNamespace) {
        _netNamespaceController.text = netNamespace;
      }
      final mtu = builder.flags.mtu.toString();
      if (_mtuController.text != mtu) {
        _mtuController.text = mtu;
      }
      final privateKey = builder.secureMode?.localPrivateKey ?? '';
      if (_privateKeyController.text != privateKey) {
        _privateKeyController.text = privateKey;
      }
      final publicKey = builder.secureMode?.localPublicKey ?? '';
      if (_publicKeyController.text != publicKey) {
        _publicKeyController.text = publicKey;
      }
      final stunServers = builder.stunServers.join('\n');
      if (_stunServersController.text != stunServers) {
        _stunServersController.text = stunServers;
      }
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    privateKeyVisible.dispose();
    publicKeyVisible.dispose();
    _socks5ProxyController.dispose();
    _netNamespaceController.dispose();
    _mtuController.dispose();
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    _stunServersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builder = widget.builder;

    return SingleChildScrollView(
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _socks5ProxyController,
                decoration: const InputDecoration(
                  labelText: 'SOCKS5 Proxy (Optional)',
                  hintText: 'socks5://host:port',
                  helperText: 'SOCKS5 proxy address for outbound traffic',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v.isEmpty) {
                    builder.socks5Proxy = null;
                  } else {
                    try {
                      builder.socks5Proxy = Uri.parse(v);
                    } catch (_) {
                      // Invalid URI, will be caught on save
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _netNamespaceController,
                decoration: const InputDecoration(
                  labelText: 'Network Namespace (Optional)',
                  helperText: 'Linux network namespace name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => builder.netNamespace = v.isEmpty ? null : v,
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ListenerListEditor(
                listeners: builder.listeners,
                onListenersChanged: (list) => builder.listeners = list,
              ),
            ],
          ),
          const SizedBox(height: 16),

          NetworkFormSection(
            title: 'Network Flags',
            icon: Icons.flag,
            children: [
              Text(
                'Protocol and performance settings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Encryption'),
                subtitle: const Text('Encrypt network traffic'),
                value: builder.flags.enableEncryption,
                onChanged: (v) => builder.flags.enableEncryption = v,
              ),
              SwitchListTile(
                title: const Text('Enable IPv6'),
                subtitle: const Text('Allow IPv6 connections'),
                value: builder.flags.enableIpv6,
                onChanged: (v) => builder.flags.enableIpv6 = v,
              ),
              SwitchListTile(
                title: const Text('Latency First'),
                subtitle: const Text('Prioritize low latency over throughput'),
                value: builder.flags.latencyFirst,
                onChanged: (v) => builder.flags.latencyFirst = v,
              ),
              SwitchListTile(
                title: const Text('Multi-Threading'),
                subtitle: const Text('Use multiple threads for processing'),
                value: builder.flags.multiThread,
                onChanged: (v) => builder.flags.multiThread = v,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mtuController,
                decoration: const InputDecoration(
                  labelText: 'MTU',
                  helperText: 'Maximum Transmission Unit (576-65535)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final mtu = int.tryParse(v);
                  if (mtu != null && mtu >= 576 && mtu <= 65535) builder.flags.mtu = mtu;
                },
              ),
              const SizedBox(height: 16),
              // Secure Mode Keys Section
              if (builder.flags.enableEncryption) ...[
                const Divider(height: 32),
                Text(
                  'Secure Mode Keys',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure cryptographic keys for secure mode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    labelText: 'Node Private Key (Base64)',
                    helperText: 'Ed25519 private key for authentication',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(privateKeyVisible.value
                              ? Icons.visibility_off
                              : Icons.visibility),
                          tooltip: privateKeyVisible.value
                              ? 'Hide private key'
                              : 'Show private key',
                          onPressed: () =>
                              privateKeyVisible.value = !privateKeyVisible.value,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate new key pair',
                          onPressed: () async {
                            final privateKey = generatePrivateKey();
                            final publicKey = await derivePublicKey(privateKey);
                            builder.secureMode = SecureMode(
                              enabled: true,
                              localPrivateKey: privateKey,
                              localPublicKey: publicKey,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  obscureText: !privateKeyVisible.value,
                  maxLines: 1,
                  onChanged: (v) async {
                    if (v.isEmpty) {
                      builder.secureMode = null;
                    } else {
                      try {
                        final publicKey = await derivePublicKey(v);
                        builder.secureMode = SecureMode(
                          enabled: true,
                          localPrivateKey: v,
                          localPublicKey: publicKey,
                        );
                      } catch (e) {
                        // Invalid key format, clear secure mode
                        builder.secureMode = null;
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _publicKeyController,
                  decoration: InputDecoration(
                    labelText: 'Node Public Key (Base64)',
                    helperText: 'Derived from private key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(publicKeyVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility),
                      tooltip: publicKeyVisible.value
                          ? 'Hide public key'
                          : 'Show public key',
                      onPressed: () =>
                          publicKeyVisible.value = !publicKeyVisible.value,
                    ),
                  ),
                  obscureText: !publicKeyVisible.value,
                  readOnly: true,
                  maxLines: 1,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          NetworkFormSection(
            title: 'STUN Servers',
            icon: Icons.cloud_sync,
            children: [
              Text(
                'STUN servers for NAT traversal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _stunServersController,
                decoration: const InputDecoration(
                  labelText: 'STUN Servers',
                  hintText: 'stun.example.com:3478',
                  helperText: 'One server per line',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (v) {
                  builder.stunServers = v.split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                },
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

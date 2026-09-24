import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../models/network_builder.dart';
import '../../../utils/crypto_utils.dart';
import 'network_form_section.dart';
import 'node_list_editor.dart';

class NetworkBasicTab extends SignalStatefulWidget {
  const NetworkBasicTab({
    super.key,
    required this.builder,
  });

  final NetworkBuilder builder;

  @override
  State<NetworkBasicTab> createState() => _NetworkBasicTabState();
}

class _NetworkBasicTabState extends State<NetworkBasicTab> {
  final secretVisible = signal(false);
  late final TextEditingController _networkNameController;
  late final TextEditingController _hostnameController;
  late final TextEditingController _networkSecretController;
  late final TextEditingController _ipv4Controller;
  late final TextEditingController _ipv6Controller;
  late final void Function() _unsubscribe;

  NetworkBuilder get builder => widget.builder;

  @override
  void initState() {
    super.initState();
    _networkNameController = TextEditingController(text: builder.networkName);
    _hostnameController = TextEditingController(text: builder.hostname ?? '');
    _networkSecretController = TextEditingController(text: builder.networkSecret ?? '');
    _ipv4Controller = TextEditingController(text: builder.ipv4 ?? '');
    _ipv6Controller = TextEditingController(text: builder.ipv6 ?? '');

    // Subscribe to builder changes to sync controllers when changed externally
    _unsubscribe = effect(() {
      if (_networkNameController.text != builder.networkName) {
        _networkNameController.text = builder.networkName;
      }
      final hostname = builder.hostname ?? '';
      if (_hostnameController.text != hostname) {
        _hostnameController.text = hostname;
      }
      final networkSecret = builder.networkSecret ?? '';
      if (_networkSecretController.text != networkSecret) {
        _networkSecretController.text = networkSecret;
      }
      final ipv4 = builder.ipv4 ?? '';
      if (_ipv4Controller.text != ipv4) {
        _ipv4Controller.text = ipv4;
      }
      final ipv6 = builder.ipv6 ?? '';
      if (_ipv6Controller.text != ipv6) {
        _ipv6Controller.text = ipv6;
      }
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    secretVisible.dispose();
    _networkNameController.dispose();
    _hostnameController.dispose();
    _networkSecretController.dispose();
    _ipv4Controller.dispose();
    _ipv6Controller.dispose();
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
          NetworkFormSection(
            title: 'Network Identity',
            icon: Icons.fingerprint,
            children: [
              TextField(
                controller: _networkNameController,
                decoration: const InputDecoration(
                  labelText: 'Network Name',
                  helperText: 'Unique identifier for this network',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => builder.networkName = v,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hostnameController,
                decoration: const InputDecoration(
                  labelText: 'Hostname (Optional)',
                  helperText: 'Device name in the network (max 32 chars)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 32,
                onChanged: (v) => builder.hostname = v.isEmpty ? null : v,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _networkSecretController,
                decoration: InputDecoration(
                  labelText: 'Network Secret (Optional)',
                  helperText: 'Shared secret for authentication',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(secretVisible.value ? Icons.visibility_off : Icons.visibility),
                        tooltip: secretVisible.value ? 'Hide secret' : 'Show secret',
                        onPressed: () => secretVisible.value = !secretVisible.value,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Generate random secret',
                        onPressed: () {
                          builder.networkSecret = generateSecretKey();
                        },
                      ),
                    ],
                  ),
                ),
                obscureText: !secretVisible.value,
                onChanged: (v) => builder.networkSecret = v.isEmpty ? null : v,
              ),
            ],
          ),
          const SizedBox(height: 16),
          NetworkFormSection(
            title: 'IP Configuration',
            icon: Icons.network_check,
            children: [
              SwitchListTile(
                title: const Text('Enable DHCP'),
                subtitle: const Text('Automatically assign IP addresses'),
                value: builder.dhcp,
                onChanged: (v) => builder.dhcp = v,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipv4Controller,
                decoration: const InputDecoration(
                  labelText: 'IPv4 Address (CIDR)',
                  hintText: '10.144.144.1/24',
                  helperText: 'Your IPv4 address in CIDR notation',
                  border: OutlineInputBorder(),
                ),
                enabled: !builder.dhcp,
                onChanged: (v) {
                  builder.ipv4 = v.isEmpty ? null : v;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipv6Controller,
                decoration: const InputDecoration(
                  labelText: 'IPv6 Address (CIDR)',
                  hintText: 'fd00::1/64',
                  helperText: 'Your IPv6 address in CIDR notation',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => builder.ipv6 = v.isEmpty ? null : v,
              ),
            ],
          ),
          const SizedBox(height: 16),
          NetworkFormSection(
            title: 'Initial Peers',
            icon: Icons.people,
            children: [
              Text(
                'Configure nodes to connect when starting the network',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              NodeListEditor(
                nodes: builder.nodes,
                onNodesChanged: (nodes) => builder.nodes = nodes,
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

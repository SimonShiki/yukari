import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../models/network_builder.dart';
import '../../signals/networks.dart';

class NetworkCreatorPage extends SignalStatefulWidget {
  const NetworkCreatorPage({super.key});

  @override
  State<NetworkCreatorPage> createState() => _NetworkCreatorPageState();
}

class _NetworkCreatorPageState extends State<NetworkCreatorPage> {
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final nameError = signal<String?>(null);
  final hostnameError = signal<String?>(null);
  final creating = signal(false);

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    nameError.dispose();
    hostnameError.dispose();
    creating.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    final hostname = _hostnameController.text.trim();

    nameError.value = null;
    hostnameError.value = null;

    if (name.isEmpty) {
      nameError.value = 'Network name cannot be empty';
      return;
    }

    if (networks.value.containsKey(name)) {
      nameError.value = 'Network name already exists';
      return;
    }

    if (hostname.isNotEmpty && hostname.length > 32) {
      hostnameError.value = 'Hostname cannot exceed 32 characters';
      return;
    }

    creating.value = true;

    try {
      final builder = NetworkBuilder()
        ..networkName = name
        ..hostname = hostname.isEmpty ? null : hostname;

      final network = builder.build();
      await addNetwork(name, network);

      if (mounted) {
        context.go('/networks/edit/$name');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create network: $e')),
        );
      }
    } finally {
      if (mounted) {
        creating.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Network')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create a new network',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be able to configure all settings after creation',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Network Name',
                      helperText: 'Unique identifier for this network',
                      errorText: nameError.value,
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !creating.value,
                    onChanged: (_) => nameError.value = null,
                    onSubmitted: (_) => _handleCreate(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hostnameController,
                    decoration: InputDecoration(
                      labelText: 'Hostname (Optional)',
                      helperText: 'Device name (max 32 characters)',
                      errorText: hostnameError.value,
                      border: const OutlineInputBorder(),
                    ),
                    maxLength: 32,
                    enabled: !creating.value,
                    onChanged: (_) => hostnameError.value = null,
                    onSubmitted: (_) => _handleCreate(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: creating.value ? null : () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: creating.value ? null : _handleCreate,
                        child: creating.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

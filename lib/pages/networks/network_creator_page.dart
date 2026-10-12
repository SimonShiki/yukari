import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:uuid/uuid.dart';

import '../../models/network.dart';
import '../../signals/networks.dart';
import '../../utils/validator.dart';

class NetworkCreatorPage extends SignalStatefulWidget {
  const NetworkCreatorPage({super.key});

  @override
  State<NetworkCreatorPage> createState() => _NetworkCreatorPageState();
}

class _NetworkCreatorPageState extends State<NetworkCreatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final creating = signal(false);

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    creating.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    creating.value = true;

    try {
      final id = const Uuid().v4();
      final hostname = _hostnameController.text.trim();
      await addNetwork(
        id,
        Network()
          ..networkName = _nameController.text.trim()
          ..hostname = hostname.isEmpty ? null : hostname,
      );

      if (mounted) {
        context.go('/networks/edit/$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create network: $e')));
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
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Network Name',
                        helperText: 'Unique identifier for this network',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !creating.value,
                      validator: (v) => validateNetworkName(v!, networkNames()),
                      onFieldSubmitted: (_) => _handleCreate(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostnameController,
                      decoration: const InputDecoration(
                        labelText: 'Hostname (Optional)',
                        helperText: 'Device name (max 32 characters)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 32,
                      enabled: !creating.value,
                      validator: (v) => validateHostname(v!),
                      onFieldSubmitted: (_) => _handleCreate(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: creating.value
                              ? null
                              : () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: creating.value ? null : _handleCreate,
                          child: creating.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
      ),
    );
  }
}

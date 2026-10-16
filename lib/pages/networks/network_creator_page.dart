import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/network.dart';
import '../../signals/networks.dart';
import '../../controllers/network_editor_validator.dart';
import '../../widgets/snackbar/app_snackbar.dart';

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
      final networkName = _nameController.text.trim();
      final hostname = _hostnameController.text.trim();
      addNetwork(
        networkName,
        Network(networkName)
          ..hostname = hostname.isEmpty ? null : hostname,
      );

      if (mounted) {
        context.go('/networks/edit/$networkName');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          context.l10n.networkCreateFailed(e.toString()),
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
      appBar: AppBar(title: Text(context.l10n.networkCreate)),
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
                      context.l10n.networkCreateHeading,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.networkCreateDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.networkName,
                        helperText: context.l10n.networkNameHelper,
                        border: OutlineInputBorder(),
                      ),
                      enabled: !creating.value,
                      validator: (v) => validateNetworkName(v!, index.value),
                      onFieldSubmitted: (_) => _handleCreate(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostnameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.networkHostname,
                        helperText: context.l10n.networkDeviceNameHelper,
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
                          child: Text(context.l10n.commonCancel),
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
                              : Text(context.l10n.commonCreate),
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

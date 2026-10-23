import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_page_controller.dart';
import '../../l10n/l10n.dart';
import '../../utils/validator.dart';
import '../../widgets/card_surface/card_surface.dart';
import '../../widgets/snackbar/app_snackbar.dart';

/// Creates a network from a name and an optional hostname, then opens its
/// editor. The store call and the navigation belong to the controller.
class NetworkCreatorPage extends StatefulWidget {
  const NetworkCreatorPage({super.key, this.controller});

  final NetworkCreatorController? controller;

  @override
  State<NetworkCreatorPage> createState() => _NetworkCreatorPageState();
}

class _NetworkCreatorPageState extends State<NetworkCreatorPage> {
  late final NetworkCreatorController _controller =
      widget.controller ??
      NetworkCreatorController(
        navigate: (route) => context.go(route),
        showMessage: (message) => showAppSnackBar(context, message),
      );
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _hostname = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _hostname.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _controller.create(name: _name.text, hostname: _hostname.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.networkCreate)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: CardSurface(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      Text(
                        l10n.networkCreateHeading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        l10n.networkCreateDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextFormField(
                        controller: _name,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _create(),
                        decoration: InputDecoration(
                          labelText: l10n.networkName,
                          helperText: l10n.networkNameHelper,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => validateNetworkName(
                          value ?? '',
                          _controller.takenNames,
                        ),
                      ),
                      TextFormField(
                        controller: _hostname,
                        maxLength: 32,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.networkHostname,
                          helperText: l10n.networkDeviceNameHelper,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => validateHostname(value ?? ''),
                        onFieldSubmitted: (_) => _create(),
                      ),
                      SignalBuilder(
                        builder: (context) => Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _controller.creating.value
                                  ? null
                                  : () => context.pop(),
                              child: Text(l10n.commonCancel),
                            ),
                            FilledButton(
                              onPressed: _controller.creating.value
                                  ? null
                                  : _create,
                              child: _controller.creating.value
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.commonCreate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

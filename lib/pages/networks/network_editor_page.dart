import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_editor_controller.dart';
import 'editor_exit_guard.dart';
import 'widgets/network_basic_tab.dart';
import 'widgets/network_advanced_tab.dart';

/// Edits the saved network [id]. Valid changes are saved as they are made.
class NetworkEditorPage extends StatefulWidget {
  const NetworkEditorPage({super.key, required this.id});

  final String id;

  @override
  State<NetworkEditorPage> createState() => _NetworkEditorPageState();
}

class _NetworkEditorPageState extends State<NetworkEditorPage> {
  final _basicForm = GlobalKey<FormState>();
  final _advancedForm = GlobalKey<FormState>();
  late final _controller = NetworkEditorController(
    id: widget.id,
    showMessage: (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    },
  );

  // Unbuilt tabs have no input yet; validating also highlights any errors.
  bool _hasInvalidInput() {
    final basicValid = _basicForm.currentState?.validate() ?? true;
    final advancedValid = _advancedForm.currentState?.validate() ?? true;
    return !(basicValid && advancedValid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerEditor(this, pageKeyOf(context), _hasInvalidInput);
  }

  @override
  void dispose() {
    unregisterEditor(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.network.peek() == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Network')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Network not found'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: SignalBuilder(
            builder: (context) =>
                Text('Edit ${_controller.networkName.value}'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Basic'),
              Tab(text: 'Advanced'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NetworkBasicTab(formKey: _basicForm, controller: _controller),
            NetworkAdvancedTab(
              formKey: _advancedForm,
              controller: _controller,
            ),
          ],
        ),
      ),
    );
  }
}

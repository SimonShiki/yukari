import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_editor_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'editor_exit_guard.dart';
import 'widgets/network_basic_tab.dart';
import 'widgets/network_advanced_tab.dart';

/// Edits the saved network [name]. Valid changes are saved as they are made.
class NetworkEditorPage extends StatefulWidget {
  const NetworkEditorPage({super.key, required this.name});

  final String name;

  @override
  State<NetworkEditorPage> createState() => _NetworkEditorPageState();
}

class _NetworkEditorPageState extends State<NetworkEditorPage> {
  final _basicForm = GlobalKey<FormState>();
  final _advancedForm = GlobalKey<FormState>();
  late final _controller = NetworkEditorController(
    name: widget.name,
    showMessage: (message) {
      if (!mounted) return;
      showAppSnackBar(context, message);
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: SignalBuilder(
            builder: (context) => Text(
              context.l10n.networkEditNamed(
                _controller.networkName.value,
              ),
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.networkBasic),
              Tab(text: context.l10n.networkAdvanced),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NetworkBasicTab(formKey: _basicForm, controller: _controller),
            NetworkAdvancedTab(formKey: _advancedForm, controller: _controller),
          ],
        ),
      ),
    );
  }
}

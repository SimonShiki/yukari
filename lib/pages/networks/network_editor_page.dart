import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_editor_controller.dart';
import 'widgets/network_basic_tab.dart';
import 'widgets/network_advanced_tab.dart';

class NetworkEditorPage extends StatefulWidget {
  const NetworkEditorPage({super.key, required this.name, this.controller});

  final String name;
  final NetworkEditorController? controller;

  @override
  State<NetworkEditorPage> createState() => _NetworkEditorPageState();
}

class _NetworkEditorPageState extends State<NetworkEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final NetworkEditorController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller = widget.controller ??
        NetworkEditorController(
          networkName: widget.name,
          showMessage: (message) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          },
          showError: (title, message) {
            if (!mounted) return;
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(Icons.error_outline, size: 48),
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        );
  }

  @override
  void didUpdateWidget(NetworkEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _controller.switchNetwork(widget.name);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      if (!_controller.loaded.value) {
        return Scaffold(
          appBar: AppBar(title: Text('Edit ${widget.name}')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (_controller.networkNotFound.value) {
        return Scaffold(
          appBar: AppBar(title: Text('Edit ${widget.name}')),
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

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 840;

          return Scaffold(
            appBar: AppBar(
              title: Text('Edit ${widget.name}'),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Basic'),
                  Tab(text: 'Advanced'),
                ],
              ),
            ),
            body: SignalBuilder(
              builder: (context) {
                final builder = _controller.builder.value;
                if (builder == null) return const SizedBox.shrink();
                return TabBarView(
                  controller: _tabController,
                  children: [
                    NetworkBasicTab(builder: builder),
                    NetworkAdvancedTab(builder: builder),
                  ],
                );
              },
            ),
            floatingActionButton: isLargeScreen
                ? FloatingActionButton.extended(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    onPressed: _controller.saving.value ? null : _controller.save,
                  )
                : FloatingActionButton(
                    onPressed: _controller.saving.value ? null : _controller.save,
                    tooltip: 'Save changes',
                    child: const Icon(Icons.save),
                  )
          );
        },
      );
    },
  );
}

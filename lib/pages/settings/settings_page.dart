import 'package:material_ui/material_ui.dart';

import '../../controllers/backend_settings_controller.dart';
import '../../models/backend.dart';
import '../../widgets/form_section/section_list.dart';
import 'widgets/backend_mode_section.dart';
import 'widgets/service_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controller});

  final BackendSettingsController? controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final BackendSettingsController _controller =
      widget.controller ??
      BackendSettingsController(
        showMessage: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        },
        confirmStopNetworks: _confirmStopNetworks,
      );

  @override
  void initState() {
    super.initState();
    _controller.refresh();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmStopNetworks(BackendKind target, int running) async {
    final (from, to) = switch (target) {
      BackendKind.service => ('the app', 'the service'),
      BackendKind.ffi => ('the service', 'the app'),
    };
    final networks = running == 1 ? '1 network' : '$running networks';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.swap_horiz_rounded),
            title: Text('Switch to $to?'),
            content: Text(
              '$networks running in $from will stop. Start them again to run '
              'them in $to.',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Switch'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: SectionList(
        children: [
          BackendModeSection(controller: _controller),
          ServiceSection(controller: _controller),
        ],
      ),
    ),
  );
}

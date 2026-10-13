import 'package:material_ui/material_ui.dart';

import '../../controllers/backend_settings_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/backend.dart';
import '../../widgets/form_section/section_list.dart';
import 'widgets/backend_mode_section.dart';
import 'widgets/interface_section.dart';
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
    final title = target == BackendKind.service
        ? context.l10n.settingsSwitchToService
        : context.l10n.settingsSwitchToApp;
    final message = target == BackendKind.service
        ? context.l10n.settingsSwitchToServiceMessage(running)
        : context.l10n.settingsSwitchToAppMessage(running);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.swap_horiz_rounded),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.settingsSwitch),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.navSettings)),
    body: SafeArea(
      child: SectionList(
        children: [
          BackendModeSection(controller: _controller),
          ServiceSection(controller: _controller),
          const InterfaceSection(),
        ],
      ),
    ),
  );
}

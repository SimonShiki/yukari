import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../controllers/backend_settings_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/form_section/section_list.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'widgets/backend_mode_section.dart';
import 'widgets/interface_section.dart';
import 'widgets/service_section.dart';
import 'widgets/switch_backend_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controller});

  final BackendSettingsController? controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final BackendSettingsController _controller =
      widget.controller ?? _createController();

  BackendSettingsController _createController() => BackendSettingsController(
    showMessage: (message) => showAppSnackBar(context, message),
    confirmStopNetworks: (kind, count) =>
        confirmSwitchBackend(context, kind, count),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.navSettings)),
    body: SafeArea(
      child: SectionList(
        children: [
          BackendModeSection(controller: _controller),
          ServiceSection(controller: _controller),
          InterfaceSection(
            language: _controller.language,
            onChanged: _controller.selectLanguage,
          ),
        ],
      ),
    ),
  );
}

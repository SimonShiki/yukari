import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../widgets/form_section/form_section.dart';
import 'editor_fields.dart';

/// Start-on-boot, which only exists where the background service can run it:
/// everywhere but Android, or on Android once the service is the backend.
class EditorStartupSection extends StatelessWidget {
  const EditorStartupSection({super.key, required this.controller});

  final NetworkEditorController controller;

  /// Whether this platform and backend can start a network with the system.
  static bool supported(BackendKind kind) =>
      !Platform.isAndroid || kind == BackendKind.service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedStartup,
      icon: Icons.power_settings_new_rounded,
      children: [
        EditorSwitch(
          controller: controller,
          name: 'autoStart',
          read: (n) => n.autoStart,
          write: (n, value) => n.autoStart = value,
          title: l10n.advancedStartOnBoot,
          subtitle: l10n.advancedStartOnBootSubtitle,
        ),
      ],
    );
  }
}

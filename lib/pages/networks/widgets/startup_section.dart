import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/form_section/form_section.dart';

/// Whether the background service starts this network on boot.
class StartupSection extends StatelessWidget {
  const StartupSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.advancedStartup,
      icon: Icons.power_settings_new_rounded,
      children: [
        SignalBuilder(
          builder: (context) => SwitchSegment(
            title: l10n.advancedStartOnBoot,
            subtitle: l10n.advancedStartOnBootSubtitle,
            value: controller.network.value!.autoStart,
            onChanged: (v) => controller.update((n) => n.autoStart = v),
          ),
        ),
      ],
    );
  }
}

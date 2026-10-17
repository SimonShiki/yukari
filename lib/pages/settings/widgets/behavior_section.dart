import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';

/// What the app does around launch: whether it starts when the user signs in.
///
/// The whole section is absent where the OS cannot start the app, as on
/// Android, so the page never offers a switch that could do nothing.
class BehaviorSection extends StatelessWidget {
  const BehaviorSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.startOnBootSupported) return const SizedBox.shrink();
    final l10n = context.l10n;
    return FormSection(
      title: l10n.settingsBehavior,
      icon: Icons.tune_rounded,
      children: [
        // Only the row that changes state rebuilds; the section frame does not.
        SignalBuilder(
          builder: (context) => SwitchSegment(
            icon: Icons.rocket_launch_outlined,
            title: l10n.settingsStartOnBoot,
            subtitle: l10n.settingsStartOnBootDescription,
            value: controller.startOnBoot.value,
            onChanged: controller.setStartOnBoot,
          ),
        ),
      ],
    );
  }
}

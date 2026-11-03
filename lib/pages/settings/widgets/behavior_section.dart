import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';

/// What the app does around launch and closing: whether it starts when the
/// user signs in, and whether it keeps running in the system tray.
///
/// Each row appears only where the OS supports it, and the whole section is
/// absent on Android, which has neither. The tray row also waits for the tray
/// controller to report that this session really has a tray icon, so a desktop
/// that would show none never offers to hide the window into it.
class BehaviorSection extends StatelessWidget {
  const BehaviorSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final showStartOnBoot = controller.startOnBootSupported;
      final showTray =
          controller.traySupported && controller.trayAvailable.value;
      if (!showStartOnBoot && !showTray) return const SizedBox.shrink();
      final l10n = context.l10n;
      return FormSection(
        title: l10n.settingsBehavior,
        icon: Icons.tune_rounded,
        children: [
          if (showStartOnBoot)
            // Only the row that changes state rebuilds; the section frame does
            // not.
            SignalBuilder(
              builder: (context) => SwitchSegment(
                icon: Icons.rocket_launch_outlined,
                title: l10n.settingsStartOnBoot,
                subtitle: l10n.settingsStartOnBootDescription,
                value: controller.startOnBoot.value,
                onChanged: controller.setStartOnBoot,
              ),
            ),
          if (showTray)
            SignalBuilder(
              builder: (context) => SwitchSegment(
                icon: Icons.vertical_align_bottom_rounded,
                title: l10n.settingsUseSystemTray,
                subtitle: l10n.settingsUseSystemTrayDescription,
                value: controller.useSystemTray.value,
                onChanged: controller.setUseSystemTray,
              ),
            ),
        ],
      );
    },
  );
}

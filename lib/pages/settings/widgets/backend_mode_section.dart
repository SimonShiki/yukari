import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/backend.dart';
import '../../../widgets/form_section/form_section.dart';
import 'backend_mode_row.dart';

/// The two rows that choose where the networks run: in the app, or in the
/// background service.
class BackendModeSection extends StatelessWidget {
  const BackendModeSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) => RadioGroup<BackendKind>(
        groupValue: controller.kind.value,
        onChanged: (kind) {
          if (kind != null) controller.select(kind);
        },
        child: FormSection(
          title: l10n.settingsWorkingMode,
          icon: Icons.lan_outlined,
          // The whole row selects too; the service row is the way in when it
          // is not installed yet.
          onTap: (index) => controller.select(
            index == 0 ? BackendKind.ffi : BackendKind.service,
          ),
          children: [
            BackendModeRow(
              kind: BackendKind.ffi,
              icon: Icons.apps_rounded,
              title: l10n.settingsModeApp,
              description: controller.appUsesSystemVpn
                  ? l10n.settingsModeAppVpnDescription
                  : l10n.settingsModeAppDescription,
            ),
            SignalBuilder(builder: _serviceRow),
          ],
        ),
      ),
    );
  }

  /// The service row, which explains why the service is not selectable yet
  /// instead of hiding it.
  Widget _serviceRow(BuildContext context) {
    final l10n = context.l10n;
    final needsRoot =
        controller.serviceState.value == ServiceState.rootRequired;
    final unreachable =
        controller.kind.value == BackendKind.service &&
        controller.status.value == BackendStatus.unavailable;
    return BackendModeRow(
      kind: BackendKind.service,
      icon: Icons.dns_outlined,
      title: l10n.settingsModeService,
      enabled: !needsRoot,
      description: switch ((needsRoot, unreachable)) {
        (true, _) => l10n.settingsNeedsRoot,
        (_, true) => l10n.settingsServiceUnreachable,
        _ => l10n.settingsModeServiceDescription,
      },
      // The unreachable hint is the one thing that must catch the eye.
      descriptionColor: unreachable && !needsRoot
          ? Theme.of(context).colorScheme.error
          : null,
    );
  }
}

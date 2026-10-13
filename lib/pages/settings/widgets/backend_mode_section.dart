import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/backend.dart';
import '../../../widgets/form_section/form_section.dart';

/// Chooses whether networks run in the app or in the background service.
class BackendModeSection extends StatelessWidget {
  const BackendModeSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final modes = [
        (
          BackendKind.ffi,
          Icons.apps_rounded,
          context.l10n.settingsModeApp,
          context.l10n.settingsModeAppDescription,
        ),
        (
          BackendKind.service,
          Icons.dns_outlined,
          context.l10n.settingsModeService,
          context.l10n.settingsModeServiceDescription,
        ),
      ];
      final unreachable =
          controller.kind.value == BackendKind.service &&
          controller.status.value == BackendStatus.unavailable;
      final rootRequired =
          controller.serviceState.value == ServiceState.rootRequired;
      final error = Theme.of(context).colorScheme.error;
      return RadioGroup<BackendKind>(
        groupValue: controller.kind.value,
        onChanged: (kind) {
          if (kind != null) controller.select(kind);
        },
        child: FormSection(
          title: context.l10n.settingsWorkingMode,
          icon: Icons.lan_outlined,
          onTap: (index) => controller.select(modes[index].$1),
          children: [
            for (final (kind, icon, title, detail) in modes)
              if (kind == BackendKind.service && rootRequired)
                M3EListItem(
                  enabled: false,
                  leading: Icon(icon),
                  headline: Text(title),
                  supportingText: Text(context.l10n.settingsNeedsRoot),
                  trailing: Radio(value: kind, enabled: false),
                )
              else
                M3EListItem(
                  leading: Icon(icon),
                  headline: Text(title),
                  supportingText: _Wrapping(
                    kind == BackendKind.service && unreachable
                        ? Text(
                            context.l10n.settingsServiceUnreachable,
                            style: TextStyle(color: error),
                          )
                        : Text(detail),
                  ),
                  trailing: Radio(value: kind),
                ),
          ],
        ),
      );
    },
  );
}

/// Lets [child] wrap onto as many lines as it needs, where [M3EListItem]
/// cuts supporting text off after one.
class _Wrapping extends StatelessWidget {
  const _Wrapping(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      DefaultTextStyle(style: DefaultTextStyle.of(context).style, child: child);
}

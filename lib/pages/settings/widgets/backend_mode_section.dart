import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../models/backend.dart';
import '../../../widgets/form_section/form_section.dart';

/// Chooses whether networks run in the app or in the background service.
class BackendModeSection extends StatelessWidget {
  const BackendModeSection({super.key, required this.controller});

  final BackendSettingsController controller;

  static const _modes = [
    (
      BackendKind.ffi,
      Icons.apps_rounded,
      'App',
      'Networks stop when Yukari closes. TUN devices need Yukari itself to '
          'run with administrator or root privileges.',
    ),
    (
      BackendKind.service,
      Icons.dns_outlined,
      'Service',
      'Networks run with full privileges, keep running after Yukari closes, '
          'and can start on boot.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final unreachable =
          controller.kind.value == BackendKind.service &&
          controller.status.value == BackendStatus.unavailable;
      final error = Theme.of(context).colorScheme.error;
      return RadioGroup<BackendKind>(
        groupValue: controller.kind.value,
        onChanged: (kind) {
          if (kind != null) controller.select(kind);
        },
        child: FormSection(
          title: 'Run networks in',
          icon: Icons.lan_outlined,
          onTap: (index) => controller.select(_modes[index].$1),
          children: [
            for (final (kind, icon, title, detail) in _modes)
              M3EListItem(
                leading: Icon(icon),
                headline: Text(title),
                supportingText: kind == BackendKind.service && unreachable
                    ? Text(
                        'Cannot reach the service. Start or reinstall it.',
                        style: TextStyle(color: error),
                      )
                    : Text(detail),
                trailing: Radio(value: kind),
              ),
          ],
        ),
      );
    },
  );
}

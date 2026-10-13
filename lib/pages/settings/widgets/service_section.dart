import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../models/backend.dart';
import '../../../widgets/form_section/form_section.dart';

/// The background service's state, and the actions that change it.
class ServiceSection extends StatelessWidget {
  const ServiceSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final state = controller.serviceState.value;
      final busy = controller.busy.value;
      final (icon, title, detail) = switch (state) {
        ServiceState.unsupported => (
          Icons.block_rounded,
          'Unavailable',
          'This platform or build has no background service',
        ),
        ServiceState.notInstalled => (
          Icons.download_rounded,
          'Not installed',
          'Install it to run networks with full privileges',
        ),
        ServiceState.stopped => (
          Icons.pause_circle_outline_rounded,
          'Stopped',
          'Installed, but not running',
        ),
        ServiceState.running => (
          Icons.check_circle_outline_rounded,
          'Running',
          'Starts with the system',
        ),
      };
      final actions = _actions(state, busy);

      return FormSection(
        title: 'Background service',
        icon: Icons.settings_suggest_outlined,
        children: [
          M3EListItem(
            leading: Icon(
              icon,
              color: state == ServiceState.running
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            headline: Text(title),
            supportingText: Text(detail),
            trailing: busy
                // Sized like the icon button it replaces.
                ? const SizedBox.square(
                    dimension: 48,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  )
                : IconButton(
                    tooltip: 'Check again',
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: actions,
              ),
            ),
        ],
      );
    },
  );

  /// The actions for [state], from least to most emphasized.
  List<Widget> _actions(ServiceState state, bool busy) {
    VoidCallback? enabled(Future<void> Function() action) =>
        busy ? null : action;
    final uninstall = TextButton(
      onPressed: enabled(controller.uninstall),
      child: const Text('Uninstall'),
    );
    final reinstall = OutlinedButton(
      onPressed: enabled(controller.install),
      child: const Text('Reinstall'),
    );
    return switch (state) {
      ServiceState.unsupported => const [],
      ServiceState.notInstalled => [
        FilledButton(
          onPressed: enabled(controller.install),
          child: const Text('Install'),
        ),
      ],
      ServiceState.stopped => [
        uninstall,
        reinstall,
        FilledButton(
          onPressed: enabled(controller.start),
          child: const Text('Start'),
        ),
      ],
      ServiceState.running => [
        uninstall,
        reinstall,
        FilledButton.tonal(
          onPressed: enabled(controller.stop),
          child: const Text('Stop'),
        ),
      ],
    };
  }
}

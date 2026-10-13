import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../backend/service_version.dart';
import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
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
      final version = controller.runningVersion.value;
      final outdated = controller.outdated.value;
      final (icon, title, detail) = switch (state) {
        ServiceState.unsupported => (
          Icons.block_rounded,
          context.l10n.settingsServiceUnavailable,
          context.l10n.settingsServiceUnsupported,
        ),
        ServiceState.rootRequired => (
          Icons.lock_outline_rounded,
          context.l10n.settingsRootRequired,
          context.l10n.settingsGrantRoot,
        ),
        ServiceState.notInstalled => (
          Icons.download_rounded,
          context.l10n.settingsServiceNotInstalled,
          context.l10n.settingsInstallServiceHint,
        ),
        ServiceState.stopped => (
          Icons.pause_circle_outline_rounded,
          context.l10n.settingsServiceStopped,
          context.l10n.settingsServiceStoppedDescription,
        ),
        ServiceState.running when outdated => (
          Icons.upgrade_rounded,
          context.l10n.settingsServiceUpdateAvailable,
          context.l10n.settingsServiceVersions(
            version.toString(),
            serviceVersion,
          ),
        ),
        ServiceState.running => (
          Icons.check_circle_outline_rounded,
          context.l10n.settingsServiceRunning,
          [
            if (version != null) context.l10n.settingsServiceVersion(version),
            context.l10n.settingsStartsWithSystem,
          ].join(' · '),
        ),
      };
      final actions = _actions(context, state, busy, outdated);

      return FormSection(
        title: context.l10n.settingsBackgroundService,
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
                    tooltip: context.l10n.settingsCheckAgain,
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
          if (controller.installing.value)
            _InstallProgress(controller.installProgress.value)
          else if (actions.isNotEmpty)
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
  List<Widget> _actions(
    BuildContext context,
    ServiceState state,
    bool busy,
    bool outdated,
  ) {
    VoidCallback? enabled(Future<void> Function() action) =>
        busy ? null : action;
    final uninstall = TextButton(
      onPressed: enabled(controller.uninstall),
      child: Text(context.l10n.settingsUninstall),
    );
    final reinstall = OutlinedButton(
      onPressed: enabled(controller.install),
      child: Text(context.l10n.settingsReinstall),
    );
    return switch (state) {
      ServiceState.unsupported || ServiceState.rootRequired => const [],
      ServiceState.notInstalled => [
        FilledButton(
          onPressed: enabled(controller.install),
          child: Text(context.l10n.settingsInstall),
        ),
      ],
      ServiceState.stopped => [
        uninstall,
        reinstall,
        FilledButton(
          onPressed: enabled(controller.start),
          child: Text(context.l10n.commonStart),
        ),
      ],
      ServiceState.running when outdated => [
        uninstall,
        OutlinedButton(
          onPressed: enabled(controller.stop),
          child: Text(context.l10n.commonStop),
        ),
        FilledButton(
          onPressed: enabled(controller.install),
          child: Text(context.l10n.settingsUpdate),
        ),
      ],
      ServiceState.running => [
        uninstall,
        reinstall,
        FilledButton.tonal(
          onPressed: enabled(controller.stop),
          child: Text(context.l10n.commonStop),
        ),
      ],
    };
  }
}

/// How far an install has come: its download's [progress], from 0 to 1, or
/// null once the download is over or of unknown size.
class _InstallProgress extends StatelessWidget {
  const _InstallProgress(this.progress);

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (progress) {
      final progress? => context.l10n.settingsDownloading(
        (progress * 100).round(),
      ),
      null => context.l10n.settingsInstalling,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          M3ELinearWavyProgressIndicator(value: progress),
        ],
      ),
    );
  }
}

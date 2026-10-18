import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:yukari_core/backend/service_version.dart';
import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/backend.dart';
import '../../../widgets/form_section/form_section.dart';
import 'install_progress.dart';
import 'service_loading_header.dart';

/// The background service's state, and the actions that change it.
class ServiceSection extends StatelessWidget {
  const ServiceSection({super.key, required this.controller});

  final BackendSettingsController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final state = controller.serviceState.value;
      final busy = controller.busy.value;
      final outdated = controller.outdated.value;
      final actions = _actions(l10n, state, busy, outdated);
      return FormSection(
        title: l10n.settingsBackgroundService,
        icon: Icons.settings_suggest_outlined,
        children: [
          // Until the first check answers, the section shows a neutral header
          // and no actions: the real state then replaces an unknown one instead
          // of contradicting what the user is already reading.
          if (!controller.stateKnown.value)
            ServiceLoadingHeader(l10n: l10n)
          else ...[
            _header(context, l10n, state, busy, outdated),
            if (controller.installing.value)
              // A download reports progress often; only this row follows it.
              SignalBuilder(
                builder: (context) =>
                    InstallProgress(progress: controller.installProgress.value),
              )
            else if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ),
          ],
        ],
      );
    },
  );

  /// One row: what the service is doing, a spinner while an action runs, and
  /// the button that re-reads the state.
  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    ServiceState state,
    bool busy,
    bool outdated,
  ) {
    final version = controller.runningVersion.value;
    final (icon, title, detail) = switch (state) {
      ServiceState.unsupported => (
        Icons.block_rounded,
        l10n.settingsServiceUnavailable,
        l10n.settingsServiceUnsupported,
      ),
      ServiceState.rootRequired => (
        Icons.lock_outline_rounded,
        l10n.settingsRootRequired,
        l10n.settingsGrantRoot,
      ),
      ServiceState.notInstalled => (
        Icons.download_rounded,
        l10n.settingsServiceNotInstalled,
        l10n.settingsInstallServiceHint,
      ),
      ServiceState.stopped => (
        Icons.pause_circle_outline_rounded,
        l10n.settingsServiceStopped,
        l10n.settingsServiceStoppedDescription,
      ),
      ServiceState.running when outdated => (
        Icons.upgrade_rounded,
        l10n.settingsServiceUpdateAvailable,
        l10n.settingsServiceVersions('${version ?? 0}', serviceVersion),
      ),
      ServiceState.running => (
        Icons.check_circle_outline_rounded,
        l10n.settingsServiceRunning,
        [
          if (version != null) l10n.settingsServiceVersion(version),
          l10n.settingsStartsWithSystem,
        ].join(' · '),
      ),
    };
    return M3EListItem(
      leading: Icon(
        icon,
        color: state == ServiceState.running
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      headline: Text(title),
      supportingText: Text(detail),
      trailing: busy
          ? serviceTrailingSpinner
          : IconButton(
              tooltip: l10n.settingsCheckAgain,
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
    );
  }

  /// The actions for [state], from least to most emphasized.
  List<Widget> _actions(
    AppLocalizations l10n,
    ServiceState state,
    bool busy,
    bool outdated,
  ) {
    VoidCallback? enabled(Future<void> Function() action) =>
        busy ? null : action;
    final uninstall = TextButton(
      onPressed: enabled(controller.uninstall),
      child: Text(l10n.settingsUninstall),
    );
    final reinstall = OutlinedButton(
      onPressed: enabled(controller.install),
      child: Text(l10n.settingsReinstall),
    );
    return switch (state) {
      ServiceState.unsupported || ServiceState.rootRequired => const <Widget>[],
      ServiceState.notInstalled => [
        FilledButton(
          onPressed: enabled(controller.install),
          child: Text(l10n.settingsInstall),
        ),
      ],
      ServiceState.stopped => [
        uninstall,
        reinstall,
        FilledButton(
          onPressed: enabled(controller.start),
          child: Text(l10n.commonStart),
        ),
      ],
      ServiceState.running when outdated => [
        uninstall,
        OutlinedButton(
          onPressed: enabled(controller.stop),
          child: Text(l10n.commonStop),
        ),
        FilledButton(
          onPressed: enabled(controller.install),
          child: Text(l10n.settingsUpdate),
        ),
      ],
      ServiceState.running => [
        uninstall,
        reinstall,
        FilledButton.tonal(
          onPressed: enabled(controller.stop),
          child: Text(l10n.commonStop),
        ),
      ],
    };
  }
}

import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/backend.dart';

/// The backend banner: where networks run, whether it is reachable, its
/// versions, and — only while it is unreachable — the way to Settings.
class BackendHeader extends StatelessWidget {
  const BackendHeader({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = context.l10n;
        final status = controller.status.value;
        final colors = _colors(status, theme.colorScheme);
        final kind = controller.backendKind.value;
        final easyTier = controller.easyTierVersion.value;
        final service = controller.serviceVersion.value;
        final versions = [
          if (easyTier != null) 'EasyTier $easyTier',
          if (service != null) l10n.homeServiceVersion(service),
        ].join(' · ');

        return Material(
          color: colors.container,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 16,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: status == BackendStatus.connecting
                      ? M3ELoadingIndicator(color: colors.accent)
                      : M3EContainer(
                          Shapes.c9SidedCookie,
                          width: 48,
                          height: 48,
                          color: colors.accent,
                          child: Icon(
                            kind == BackendKind.ffi
                                ? Icons.apps_rounded
                                : Icons.dns_rounded,
                            color: colors.onAccent,
                          ),
                        ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Flexible(
                            child: Text(
                              kind == BackendKind.ffi
                                  ? l10n.homeRunningInApp
                                  : l10n.homeRunningAsService,
                              style: theme.emphasizedTextTheme.titleMedium
                                  ?.copyWith(color: colors.onContainer),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Badge(
                            label: Text(_badge(l10n, status)),
                            backgroundColor: colors.accent,
                            textColor: colors.onAccent,
                          ),
                        ],
                      ),
                      if (versions.isNotEmpty)
                        Text(
                          versions,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onContainer,
                          ),
                        ),
                    ],
                  ),
                ),
                if (controller.showSettings.value)
                  TextButton(
                    onPressed: () => context.go('/settings'),
                    child: Text(l10n.navSettings),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _badge(AppLocalizations l10n, BackendStatus status) => switch (status) {
  BackendStatus.ready => l10n.homeReady,
  BackendStatus.connecting => l10n.homeConnecting,
  BackendStatus.unavailable => l10n.homeUnreachable,
};

({Color container, Color onContainer, Color accent, Color onAccent}) _colors(
  BackendStatus status,
  ColorScheme scheme,
) => switch (status) {
  BackendStatus.ready => (
    container: scheme.primaryContainer,
    onContainer: scheme.onPrimaryContainer,
    accent: scheme.primary,
    onAccent: scheme.onPrimary,
  ),
  BackendStatus.connecting => (
    container: scheme.secondaryContainer,
    onContainer: scheme.onSecondaryContainer,
    accent: scheme.secondary,
    onAccent: scheme.onSecondary,
  ),
  BackendStatus.unavailable => (
    container: scheme.errorContainer,
    onContainer: scheme.onErrorContainer,
    accent: scheme.error,
    onAccent: scheme.onError,
  ),
};

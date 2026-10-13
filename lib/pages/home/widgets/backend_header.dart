import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/home_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/backend.dart';

/// Where networks run, whether that backend can take requests, and the
/// versions it runs.
class BackendHeader extends StatelessWidget {
  const BackendHeader({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final status = controller.status.value;
      final (icon, title) = switch (controller.kind.value) {
        BackendKind.ffi => (Icons.apps_rounded, context.l10n.homeRunningInApp),
        BackendKind.service => (
          Icons.dns_rounded,
          context.l10n.homeRunningAsService,
        ),
      };
      final (
        container,
        onContainer,
        accent,
        onAccent,
        label,
      ) = switch (status) {
        BackendStatus.ready => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
          colors.primary,
          colors.onPrimary,
          context.l10n.homeReady,
        ),
        BackendStatus.connecting => (
          colors.secondaryContainer,
          colors.onSecondaryContainer,
          colors.secondary,
          colors.onSecondary,
          context.l10n.homeConnecting,
        ),
        BackendStatus.unavailable => (
          colors.errorContainer,
          colors.onErrorContainer,
          colors.error,
          colors.onError,
          context.l10n.homeUnreachable,
        ),
      };
      final versions = [
        if (controller.easyTierVersion.value case final version?)
          'EasyTier $version',
        if (controller.serviceVersion.value case final version?)
          context.l10n.homeServiceVersion(version),
      ];

      return Material(
        color: container,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              if (status == BackendStatus.connecting)
                M3ELoadingIndicator(
                  color: accent,
                  constraints: BoxConstraints.tight(const Size.square(48)),
                )
              else
                M3EContainer(
                  Shapes.c9SidedCookie,
                  width: 48,
                  height: 48,
                  color: accent,
                  child: Icon(icon, size: 24, color: onAccent),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      title,
                      style: theme.emphasizedTextTheme.titleMedium?.copyWith(
                        color: onContainer,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Badge(
                          backgroundColor: accent,
                          textColor: onAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          label: Text(label),
                        ),
                        Text(
                          versions.join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status == BackendStatus.unavailable)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: onContainer),
                  onPressed: () => context.go('/settings'),
                  child: Text(context.l10n.navSettings),
                ),
            ],
          ),
        ),
      );
    },
  );
}

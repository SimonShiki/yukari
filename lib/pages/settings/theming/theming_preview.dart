import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/theming_controller.dart';
import '../../../l10n/l10n.dart';

/// The page's live preview: a mock Yukari screen drawn with the settings'
/// scheme, rebuilding as the palette, variant, appearance or the platform
/// colors change.
class ThemingPreview extends StatelessWidget {
  const ThemingPreview({super.key, required this.controller});

  final ThemingController controller;

  /// The mock surfaces whose colors are the scheme's own, so tests can read
  /// the colors the preview actually painted.
  static const surfaceKey = Key('theming-preview-surface');
  static const cardKey = Key('theming-preview-card');
  static const accentKey = Key('theming-preview-accent');

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final brightness = controller.brightnessFor(
        MediaQuery.platformBrightnessOf(context),
      );
      final theme = controller.themeFor(brightness);
      final colors = theme.colorScheme;
      final l10n = context.l10n;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Theme(
            data: theme,
            child: Material(
              key: surfaceKey,
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hub_rounded,
                            size: 20,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Yukari',
                            style: theme.emphasizedTextTheme.titleMedium
                                ?.copyWith(color: colors.onSurface),
                          ),
                        ),
                        Icon(
                          Icons.settings_outlined,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Material(
                      key: cardKey,
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lan_rounded,
                                size: 20,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.networkTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.homeRunningInApp,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Material(
                          key: accentKey,
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.cardRunning,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 96,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

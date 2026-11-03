import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:yukari_core/models/models.dart';
import 'package:yukari/utils/theme_provider.dart';

/// The font set the Windows theme must pin, in order.
const _windowsFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI Symbol',
];

ThemeData _theme({
  Brightness brightness = Brightness.light,
  ThemePreference mode = ThemePreference.system,
  ThemePalette palette = ThemePalette.deepPurple,
  M3EColorVariant variant = M3EColorVariant.neutral,
  bool useSystemColor = false,
  ColorScheme? systemScheme,
}) => buildTheme(
  brightness: brightness,
  mode: mode,
  palette: palette,
  variant: variant,
  useSystemColor: useSystemColor,
  systemScheme: systemScheme,
);

void main() {
  group('theme fonts', () {
    test('pins the Windows font stack on every text style', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final theme in [
        _theme(),
        _theme(brightness: Brightness.dark),
      ]) {
        for (final style in [
          theme.textTheme.displayLarge,
          theme.textTheme.titleMedium,
          theme.textTheme.labelSmall,
          theme.textTheme.bodyMedium,
          theme.primaryTextTheme.bodyMedium,
        ]) {
          expect(style?.fontFamily, 'Segoe UI');
          expect(style?.fontFamilyFallback, _windowsFallback);
        }
      }
    });

    test("keeps Flutter's own fonts where Flutter already pins them", () {
      // flutter_test reports the host as Android, which Flutter pins itself.
      expect(defaultTargetPlatform, TargetPlatform.android);

      final theme = _theme();

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, isNull);
    });

    testWidgets('the localized theme keeps the pinned stack for Chinese', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      // The binding verifies foundation debug variables before tearDowns run,
      // so the override is cleared here rather than in an addTearDown.
      try {
        TextTheme? localized;
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(),
            locale: const Locale('zh'),
            supportedLocales: const [Locale('zh')],
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Builder(
              builder: (context) {
                localized = Theme.of(context).textTheme;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(localized?.bodyMedium?.fontFamily, 'Segoe UI');
        expect(localized?.bodyMedium?.fontFamilyFallback, _windowsFallback);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('color scheme', () {
    test('gives every palette its own seed colour', () {
      final seeds = ThemePalette.values.map((palette) => palette.seedColor);
      expect(seeds.toSet(), hasLength(ThemePalette.values.length));
    });

    test('generates the scheme from the palette and the variant', () {
      final blue = _theme(palette: ThemePalette.blue).colorScheme;
      final red = _theme(palette: ThemePalette.red).colorScheme;
      final monochrome = _theme(
        palette: ThemePalette.blue,
        variant: M3EColorVariant.monochrome,
      ).colorScheme;

      expect(blue.primary, isNot(red.primary));
      expect(blue.primary, isNot(monochrome.primary));
    });

    test('returns the whole platform scheme when asked', () {
      final system = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      );

      final dynamic = _theme(
        useSystemColor: true,
        systemScheme: system,
      ).colorScheme;

      expect(dynamic, system, reason: 'no role is mixed in from the palette');
      // Text and container roles must stay on the platform's colors too.
      expect(dynamic.surface, system.surface);
      expect(dynamic.onSurface, system.onSurface);
      expect(dynamic.onSurfaceVariant, system.onSurfaceVariant);
      expect(dynamic.outline, system.outline);
      expect(dynamic.primary, system.primary);
      expect(dynamic.onPrimaryContainer, system.onPrimaryContainer);
      expect(dynamic.onSecondaryContainer, system.onSecondaryContainer);
      expect(dynamic.onTertiaryContainer, system.onTertiaryContainer);
      expect(dynamic.onErrorContainer, system.onErrorContainer);
    });

    test('falls back to the generated scheme when not asked', () {
      final system = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      );
      final generated = _theme(
        useSystemColor: false,
        systemScheme: system,
      ).colorScheme;

      expect(generated.primary, isNot(system.primary));
      expect(
        _theme(useSystemColor: true).colorScheme,
        generated,
        reason: 'no platform scheme means the palette still applies',
      );
    });

    test('OLED is a dark scheme with black surfaces', () {
      final oled = _theme(
        brightness: Brightness.dark,
        mode: ThemePreference.oled,
      ).colorScheme;
      final dark = _theme(
        brightness: Brightness.dark,
        mode: ThemePreference.dark,
      ).colorScheme;

      expect(oled.brightness, Brightness.dark);
      expect(oled.surface, Colors.black);
      expect(oled.surfaceContainerLowest, Colors.black);
      expect(dark.surface, isNot(Colors.black));
      expect(
        _theme(
          mode: ThemePreference.oled,
        ).colorScheme.surface,
        isNot(Colors.black),
        reason: 'OLED only darkens the dark scheme',
      );
    });

    test('OLED darkens the platform scheme, keeping its other roles', () {
      final system = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      );

      final oled = _theme(
        brightness: Brightness.dark,
        mode: ThemePreference.oled,
        useSystemColor: true,
        systemScheme: system,
      ).colorScheme;

      expect(oled.surface, Colors.black);
      expect(oled.surfaceDim, Colors.black);
      expect(oled.surfaceContainerHighest, const Color(0xFF222222));
      expect(oled.primary, system.primary);
      expect(oled.onSurface, system.onSurface);
      expect(oled.onPrimaryContainer, system.onPrimaryContainer);
      expect(oled.outline, system.outline);
    });

    test('maps each preference to its theme mode', () {
      expect(themeModeFor(ThemePreference.system), ThemeMode.system);
      expect(themeModeFor(ThemePreference.light), ThemeMode.light);
      expect(themeModeFor(ThemePreference.dark), ThemeMode.dark);
      expect(themeModeFor(ThemePreference.oled), ThemeMode.dark);
    });
  });
}

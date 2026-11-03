import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

import 'package:yukari_core/models/theme.dart';

/// The colour [palette] seeds the app's colour scheme with.
extension ThemePaletteSeed on ThemePalette {
  Color get seedColor => switch (this) {
    ThemePalette.deepPurple => Colors.deepPurple,
    ThemePalette.blue => Colors.blue,
    ThemePalette.teal => Colors.teal,
    ThemePalette.green => Colors.green,
    ThemePalette.amber => Colors.amber,
    ThemePalette.orange => Colors.orange,
    ThemePalette.pink => Colors.pink,
    ThemePalette.red => Colors.red,
  };
}

/// The [ThemeMode] that applies [preference].
ThemeMode themeModeFor(ThemePreference preference) => switch (preference) {
  ThemePreference.system => ThemeMode.system,
  ThemePreference.light => ThemeMode.light,
  ThemePreference.dark || ThemePreference.oled => ThemeMode.dark,
};

// See https://github.com/flutter/flutter/issues/103811
const _windowsFontFamily = 'Segoe UI';
const _windowsFontFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI Symbol',
];

/// The fixed font set [platform] renders with, or null to keep Flutter's
/// default.
({String family, List<String> fallback})? _fontStackFor(
  TargetPlatform platform,
) => switch (platform) {
  TargetPlatform.windows => (
    family: _windowsFontFamily,
    fallback: _windowsFontFallback,
  ),
  _ => null,
};

/// Builds the colour scheme the app draws [brightness] with.
///
/// With [useSystemColor] on and a [systemScheme] for [brightness], the whole
/// scheme is the platform's, text colours included. Otherwise [palette] and
/// [variant] generate it. [ThemePreference.oled] darkens the dark scheme's
/// surfaces to black.
ColorScheme buildColorScheme({
  required Brightness brightness,
  required ThemePreference mode,
  required ThemePalette palette,
  required M3EColorVariant variant,
  required bool useSystemColor,
  ColorScheme? systemScheme,
}) {
  final scheme = useSystemColor && systemScheme != null
      ? systemScheme
      : M3EColorScheme.generate(
          seedColor: palette.seedColor,
          brightness: brightness,
          variant: variant,
        );
  return mode == ThemePreference.oled && brightness == Brightness.dark
      ? _oledSurfaces(scheme)
      : scheme;
}

/// Builds the app's theme for [brightness] from a set of theme settings.
///
/// Pass the platform's dynamic scheme for [brightness] as [systemScheme].
ThemeData buildTheme({
  required Brightness brightness,
  required ThemePreference mode,
  required ThemePalette palette,
  required M3EColorVariant variant,
  required bool useSystemColor,
  ColorScheme? systemScheme,
}) {
  final fonts = _fontStackFor(defaultTargetPlatform);
  return ThemeData(
    useMaterial3: true,
    colorScheme: buildColorScheme(
      brightness: brightness,
      mode: mode,
      palette: palette,
      variant: variant,
      useSystemColor: useSystemColor,
      systemScheme: systemScheme,
    ),
    fontFamily: fonts?.family,
    fontFamilyFallback: fonts?.fallback,
  );
}

/// The dark scheme's surface ramp, stepped from pure black for OLED panels.
ColorScheme _oledSurfaces(ColorScheme scheme) => scheme.copyWith(
  surface: Colors.black,
  surfaceDim: Colors.black,
  surfaceContainerLowest: Colors.black,
  surfaceContainerLow: const Color(0xFF0A0A0A),
  surfaceContainer: const Color(0xFF121212),
  surfaceContainerHigh: const Color(0xFF1A1A1A),
  surfaceContainerHighest: const Color(0xFF222222),
);

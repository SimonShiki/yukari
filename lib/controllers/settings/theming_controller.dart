import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

import 'package:yukari_core/models/models.dart';

import '../../signals/settings.dart';
import '../../signals/system_color.dart';
import '../../utils/theme_provider.dart';

/// The theming page's signals and actions: the theme settings, and the schemes
/// they generate for the page's previews.
class ThemingController {
  /// Whether the app draws with the OS wallpaper colors.
  ReadonlySignal<bool> get useSystemColor => settings.theme.useSystemColor;

  /// The seed color the palette presets generate from.
  ReadonlySignal<ThemePalette> get palette => settings.theme.palette;

  /// The shape of the generated color scheme.
  ReadonlySignal<M3EColorVariant> get variant => settings.theme.variant;

  /// Which appearance the app uses.
  ReadonlySignal<ThemePreference> get mode => settings.theme.mode;

  /// Draws with the OS wallpaper colors when [useSystemColor] is true.
  void setUseSystemColor(bool useSystemColor) =>
      settings.theme.setUseSystemColor(useSystemColor);

  /// Generates the scheme from [palette].
  void selectPalette(ThemePalette palette) =>
      settings.theme.setPalette(palette);

  /// Generates the scheme with [variant].
  void selectVariant(M3EColorVariant variant) =>
      settings.theme.setVariant(variant);

  /// Shows the app with [mode].
  void selectMode(ThemePreference mode) => settings.theme.setMode(mode);

  /// The brightness [mode] previews at: the platform's in system mode, and
  /// the mode's own otherwise.
  Brightness brightnessFor(Brightness platformBrightness) =>
      switch (themeModeFor(mode.value)) {
        ThemeMode.system => platformBrightness,
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
      };

  /// The theme that draws the preview at [brightness].
  ///
  /// With [useSystemColor] on, it uses the platform scheme for [brightness]
  /// when the platform reports one; without one the palette generates the
  /// scheme, so the preview is still the app's own.
  ThemeData themeFor(Brightness brightness) => buildTheme(
    brightness: brightness,
    mode: mode.value,
    palette: palette.value,
    variant: variant.value,
    useSystemColor: useSystemColor.value,
    systemScheme: switch (brightness) {
      Brightness.light => systemLightColorScheme.value,
      Brightness.dark => systemDarkColorScheme.value,
    },
  );

  late final _lightSchemes = computed(() => _schemes(Brightness.light));
  late final _darkSchemes = computed(() => _schemes(Brightness.dark));

  List<ColorScheme> schemesFor(Brightness brightness) =>
      (brightness == Brightness.light ? _lightSchemes : _darkSchemes).value;

  List<ColorScheme> _schemes(Brightness brightness) => [
    for (final palette in ThemePalette.values)
      buildColorScheme(
        brightness: brightness,
        mode: mode.value,
        palette: palette,
        variant: variant.value,
        useSystemColor: false,
      ),
  ];

  void dispose() {
    _lightSchemes.dispose();
    _darkSchemes.dispose();
  }
}

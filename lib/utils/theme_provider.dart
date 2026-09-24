import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:signals/signals.dart';

const Color _defaultSeedColor = Colors.deepPurple;

/// Global theme preference signals.
///
/// These signals control the application's visual theme and are directly mutable
/// by UI components (e.g., settings screens). Direct mutation is intentional
/// for user preference controls.

/// Whether to use system dynamic colors (Material You).
///
/// **Mutation**: Set directly via `useDynamicColors.value = bool`
/// **Read**: Access via `useDynamicColors.value` or subscribe in effects
///
/// When true, extracts colors from system wallpaper (Android 12+).
/// When false, uses [_defaultSeedColor] for theme generation.
final useDynamicColors = signal(true);

/// Current theme mode (light, dark, or system).
///
/// **Mutation**: Set directly via `themeMode.value = ThemeMode`
/// **Read**: Access via `themeMode.value` or subscribe in effects
///
/// Use [ThemeMode.system] to follow platform brightness settings.
final themeMode = signal(ThemeMode.system);

/// Material 3 color variant for theme generation.
///
/// **Mutation**: Set directly via `variant.value = M3EColorVariant`
/// **Read**: Access via `variant.value` or subscribe in effects
///
/// Controls the tonal palette variant (neutral, vibrant, expressive, etc.).
final variant = signal(M3EColorVariant.neutral);

/// Internal theme builder that generates [ThemeData] based on current signals.
///
/// Reacts to [useDynamicColors] and [variant] signals to construct the color scheme.
/// Called by [getLightTheme] and [getDarkTheme] with the appropriate brightness.
ThemeData _buildTheme(Brightness brightness, ColorScheme? dynamicColorScheme) {
  final systemScheme = useDynamicColors.value ? dynamicColorScheme : null;
  final colorScheme = brightness == Brightness.light
      ? M3EColorScheme.light(
          seedColor: _defaultSeedColor,
          variant: variant.value,
          systemColorScheme: systemScheme,
        )
      : M3EColorScheme.dark(
          seedColor: _defaultSeedColor,
          variant: variant.value,
          systemColorScheme: systemScheme,
        );

  return ThemeData(useMaterial3: true, colorScheme: colorScheme);
}

/// Build a light theme using current signal values.
///
/// Pass system [dynamicColorScheme] if available (Android 12+).
/// Returns a [ThemeData] that reacts to [useDynamicColors] and [variant] signals.
ThemeData getLightTheme(ColorScheme? dynamicColorScheme) =>
    _buildTheme(Brightness.light, dynamicColorScheme);

/// Build a dark theme using current signal values.
///
/// Pass system [dynamicColorScheme] if available (Android 12+).
/// Returns a [ThemeData] that reacts to [useDynamicColors] and [variant] signals.
ThemeData getDarkTheme(ColorScheme? dynamicColorScheme) =>
    _buildTheme(Brightness.dark, dynamicColorScheme);

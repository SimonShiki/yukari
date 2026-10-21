import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

final Signal<ColorScheme?> _light = signal<ColorScheme?>(null);
final Signal<ColorScheme?> _dark = signal<ColorScheme?>(null);

/// The platform's dynamic light color scheme, or null when it has none.
ReadonlySignal<ColorScheme?> get systemLightColorScheme => _light;

/// The platform's dynamic dark color scheme, or null when it has none.
ReadonlySignal<ColorScheme?> get systemDarkColorScheme => _dark;

/// Resolves the platform's dynamic color schemes, before the app's first frame.
///
/// Reads the OS' core palette first and its accent color second, as
/// `DynamicColorBuilder` does. A platform with neither, or one whose plugin
/// fails, leaves both schemes null and the app keeps its palette scheme.
Future<void> initSystemColorSchemes() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) {
      updateSystemColorSchemes(
        light: palette.toColorScheme(),
        dark: palette.toColorScheme(brightness: Brightness.dark),
      );
      return;
    }
  } on PlatformException {
    // No core palette: try the platform's accent color instead.
  }

  try {
    final accent = await DynamicColorPlugin.getAccentColor();
    if (accent != null) {
      updateSystemColorSchemes(
        light: ColorScheme.fromSeed(seedColor: accent),
        dark: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
      );
    }
  } on PlatformException {
    // No dynamic color on this platform.
  }
}

/// Records the platform's dynamic schemes; null means the platform cannot
/// provide that scheme.
void updateSystemColorSchemes({ColorScheme? light, ColorScheme? dark}) {
  batch(() {
    _light.value = light;
    _dark.value = dark;
  });
}

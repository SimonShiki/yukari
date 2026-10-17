import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

final Signal<ColorScheme?> _light = signal<ColorScheme?>(null);
final Signal<ColorScheme?> _dark = signal<ColorScheme?>(null);

/// The platform's dynamic light color scheme, or null when it has none.
ReadonlySignal<ColorScheme?> get systemLightColorScheme => _light;

/// The platform's dynamic dark color scheme, or null when it has none.
ReadonlySignal<ColorScheme?> get systemDarkColorScheme => _dark;

/// Records the platform's dynamic schemes, as `DynamicColorBuilder` reports
/// them; null means the platform cannot provide that scheme, such as on
/// desktop. Tests call this to inject schemes.
void updateSystemColorSchemes({ColorScheme? light, ColorScheme? dark}) {
  batch(() {
    _light.value = light;
    _dark.value = dark;
  });
}

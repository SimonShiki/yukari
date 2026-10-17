import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:material_ui/material_ui.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/pages/settings/theming/palette_picker.dart';
import 'package:yukari/pages/settings/theming_page.dart';
import 'package:yukari/utils/theme_provider.dart';

import 'router_support.dart';

/// The scheme the settings generate, as the theming page's surfaces draw it.
ColorScheme scheme({
  Brightness brightness = Brightness.light,
  ThemePreference mode = ThemePreference.system,
  ThemePalette palette = ThemePalette.deepPurple,
  M3EColorVariant variant = M3EColorVariant.neutral,
  bool useSystemColor = false,
  ColorScheme? systemScheme,
}) => buildColorScheme(
  brightness: brightness,
  mode: mode,
  palette: palette,
  variant: variant,
  useSystemColor: useSystemColor,
  systemScheme: systemScheme,
);

/// The app's own theme, as the app frames the theming surfaces.
ThemeData appTheme() => buildTheme(
  brightness: Brightness.light,
  mode: ThemePreference.system,
  palette: ThemePalette.deepPurple,
  variant: M3EColorVariant.neutral,
  useSystemColor: false,
);

/// Pumps the full theming page, as the app opens it full screen.
Future<void> pumpThemingPage(WidgetTester tester) =>
    pumpApp(tester, home: const ThemingPage(), theme: appTheme());

/// The preset [palette]'s swatch on the theming page.
Finder swatch(ThemePalette palette) => find.byWidgetPredicate(
  (widget) => widget is PaletteSwatch && widget.palette == palette,
);

/// The color of the [Material] painted at [key], as the previews paint it.
Color? colorOf(WidgetTester tester, Key key) =>
    tester.widget<Material>(find.byKey(key)).color;

import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/controllers/theming_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/settings/theming/theming_preview.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/signals/system_color.dart';
import 'package:yukari/system/autostart.dart';

import '../router_support.dart';
import '../theming_test_support.dart';

/// Pumps the live preview on its own, with the app's theme.
Future<void> pumpPreview(WidgetTester tester) => pumpApp(
  tester,
  home: ThemingPreview(controller: ThemingController()),
  theme: appTheme(),
);

/// The color the preview draws its title text with.
Color? titleColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('Yukari')).style?.color;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: const UnsupportedAutostart());
    settings.theme.setVariant(M3EColorVariant.neutral);
  });

  tearDown(() => updateSystemColorSchemes());

  testWidgets(
    'the preview follows the platform scheme while system colors are on',
    (tester) async {
      settings.theme.setUseSystemColor(true);
      final lightSystem = ColorScheme.fromSeed(seedColor: Colors.orange);
      final darkSystem = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      );
      updateSystemColorSchemes(light: lightSystem, dark: darkSystem);
      await pumpPreview(tester);

      expect(colorOf(tester, ThemingPreview.surfaceKey), lightSystem.surface);
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        lightSystem.primaryContainer,
      );
      expect(
        colorOf(tester, ThemingPreview.cardKey),
        lightSystem.surfaceContainerHigh,
      );
      expect(titleColor(tester), lightSystem.onSurface);

      settings.theme.setMode(ThemePreference.dark);
      await tester.pump();
      await tester.pump();
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        darkSystem.primaryContainer,
      );
      expect(
        colorOf(tester, ThemingPreview.cardKey),
        darkSystem.surfaceContainerHigh,
      );
      expect(titleColor(tester), darkSystem.onSurface);

      // A platform without dynamic colors falls back to the palette scheme.
      updateSystemColorSchemes();
      await tester.pump();
      final fallback = scheme(
        brightness: Brightness.dark,
        mode: ThemePreference.dark,
        useSystemColor: true,
      );
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        fallback.primaryContainer,
      );
      expect(colorOf(tester, ThemingPreview.surfaceKey), fallback.surface);
    },
  );

  testWidgets('OLED darkens the platform scheme the preview draws', (
    tester,
  ) async {
    settings.theme.setUseSystemColor(true);
    settings.theme.setMode(ThemePreference.oled);
    final darkSystem = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.dark,
    );
    updateSystemColorSchemes(
      light: ColorScheme.fromSeed(seedColor: Colors.orange),
      dark: darkSystem,
    );
    await pumpPreview(tester);

    expect(colorOf(tester, ThemingPreview.surfaceKey), Colors.black);
    expect(
      colorOf(tester, ThemingPreview.accentKey),
      darkSystem.primaryContainer,
    );
    expect(titleColor(tester), darkSystem.onSurface);
  });

  testWidgets('system mode follows the platform brightness', (tester) async {
    settings.theme.setUseSystemColor(false);
    await pumpPreview(tester);
    expect(colorOf(tester, ThemingPreview.surfaceKey), scheme().surface);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump();
    expect(
      colorOf(tester, ThemingPreview.surfaceKey),
      scheme(brightness: Brightness.dark).surface,
    );
    expect(settings.theme.mode.value, ThemePreference.system);
  });
}

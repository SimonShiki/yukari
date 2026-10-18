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

      final lightExpected = scheme(
        useSystemColor: true,
        systemScheme: lightSystem,
      );
      expect(colorOf(tester, ThemingPreview.surfaceKey), lightExpected.surface);
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        lightExpected.primaryContainer,
      );
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        lightSystem.primaryContainer,
      );
      expect(
        colorOf(tester, ThemingPreview.cardKey),
        lightExpected.surfaceContainerHigh,
      );

      settings.theme.setMode(ThemePreference.dark);
      await tester.pump();
      await tester.pump();
      final darkExpected = scheme(
        brightness: Brightness.dark,
        mode: ThemePreference.dark,
        useSystemColor: true,
        systemScheme: darkSystem,
      );
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        darkExpected.primaryContainer,
      );
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        darkSystem.primaryContainer,
      );

      // A platform without dynamic colors falls back to the palette scheme.
      updateSystemColorSchemes();
      await tester.pump();
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        scheme(
          brightness: Brightness.dark,
          mode: ThemePreference.dark,
          useSystemColor: true,
        ).primaryContainer,
      );
    },
  );

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

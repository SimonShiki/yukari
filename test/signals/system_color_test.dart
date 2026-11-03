import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/main.dart';
import 'package:yukari/pages/about/about_page.dart';
import 'package:yukari/router.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/signals/system_color.dart';
import 'package:yukari/system/autostart.dart';

/// Five tonal palettes of thirteen tones each, concatenated, as the plugin
/// channel sends them for `CorePalette.fromList`.
final _corePalettePayload = Int32List.fromList([
  for (var palette = 0; palette < 5; palette++)
    for (var tone = 0; tone < 13; tone++)
      Color.fromARGB(255, 32 + palette * 40, 64 + tone * 8, 96).toARGB32(),
]);

/// Serves the dynamic color plugin channel the given platform values.
void mockDynamicColor({
  Int32List? corePalette,
  Color? accentColor,
  bool failing = false,
}) => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(DynamicColorPlugin.channel, (call) async {
      if (failing) throw PlatformException(code: 'unavailable');
      return switch (call.method) {
        DynamicColorPlugin.methodName => corePalette,
        DynamicColorPlugin.accentColorMethodName => accentColor?.toARGB32(),
        _ => null,
      };
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DynamicColorPlugin.channel, null);
    updateSystemColorSchemes();
    appRouter.go('/');
  });

  test('default to null and follow the platform schemes', () {
    expect(systemLightColorScheme.value, isNull);
    expect(systemDarkColorScheme.value, isNull);

    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    updateSystemColorSchemes(light: light, dark: dark);

    expect(systemLightColorScheme.value, light);
    expect(systemDarkColorScheme.value, dark);

    updateSystemColorSchemes();
    expect(systemLightColorScheme.value, isNull);
    expect(systemDarkColorScheme.value, isNull);
  });

  group('initSystemColorSchemes', () {
    test('resolves the core palette into both brightnesses', () async {
      mockDynamicColor(corePalette: _corePalettePayload);
      await initSystemColorSchemes();

      final palette = (await DynamicColorPlugin.getCorePalette())!;
      expect(systemLightColorScheme.value, palette.toColorScheme());
      expect(
        systemDarkColorScheme.value,
        palette.toColorScheme(brightness: Brightness.dark),
      );
    });

    test('prefers the core palette over the accent color', () async {
      mockDynamicColor(
        corePalette: _corePalettePayload,
        accentColor: Colors.amber,
      );
      await initSystemColorSchemes();

      expect(
        systemLightColorScheme.value,
        isNot(ColorScheme.fromSeed(seedColor: Colors.amber)),
        reason: 'the accent color is only the fallback',
      );
    });

    test('falls back to the accent color without a core palette', () async {
      mockDynamicColor(accentColor: Colors.amber);
      await initSystemColorSchemes();

      expect(
        systemLightColorScheme.value,
        ColorScheme.fromSeed(seedColor: Colors.amber),
      );
      expect(
        systemDarkColorScheme.value,
        ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      );
    });

    test('leaves the schemes unset without dynamic color', () async {
      mockDynamicColor();
      await initSystemColorSchemes();

      expect(systemLightColorScheme.value, isNull);
      expect(systemDarkColorScheme.value, isNull);
    });

    test('does not throw when the platform has no plugin', () async {
      await initSystemColorSchemes();

      expect(systemLightColorScheme.value, isNull);
      expect(systemDarkColorScheme.value, isNull);
    });

    test('does not throw when the plugin fails', () async {
      mockDynamicColor(failing: true);
      await initSystemColorSchemes();

      expect(systemLightColorScheme.value, isNull);
      expect(systemDarkColorScheme.value, isNull);
    });

    testWidgets('the app paints the first frame with the platform scheme', (
      tester,
    ) async {
      mockDynamicColor(corePalette: _corePalettePayload);
      await initSystemColorSchemes();
      SharedPreferences.setMockInitialValues({});
      await initSettings(autostart: const UnsupportedAutostart());
      appRouter.go('/about');

      await tester.pumpWidget(const Yukari());

      final light = systemLightColorScheme.value!;
      final dark = systemDarkColorScheme.value!;
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(settings.theme.useSystemColor.value, isTrue);
      expect(app.theme?.colorScheme, light);
      expect(app.darkTheme?.colorScheme, dark);
      expect(
        Theme.of(tester.element(find.byType(AboutPage))).colorScheme,
        light,
        reason: 'the first frame the user sees is already the system scheme',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}

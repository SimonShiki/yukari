import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/settings/theming/palette_picker.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/autostart.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';

import '../router_support.dart';
import '../theming_test_support.dart';

PaletteSwatchPainter _painterOf(WidgetTester tester, Finder parent) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: parent,
                matching: find.byKey(PaletteSwatch.paintKey),
              ),
            )
            .painter!
        as PaletteSwatchPainter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: const UnsupportedAutostart());
    settings.theme.setVariant(M3EColorVariant.neutral);
  });

  testWidgets('swatch reports taps and exposes selection semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final blue = scheme(palette: ThemePalette.blue);
    var taps = 0;
    await pumpApp(
      tester,
      home: Scaffold(
        body: Center(
          child: PaletteSwatch(
            palette: ThemePalette.blue,
            scheme: blue,
            label: 'Blue',
            selected: false,
            onTap: () => taps++,
          ),
        ),
      ),
      theme: appTheme(),
    );

    final swatchFinder = find.byType(PaletteSwatch);
    expect(_painterOf(tester, swatchFinder).scheme, blue);
    expect(_painterOf(tester, swatchFinder).selected, isFalse);

    await tester.tap(swatchFinder);
    expect(taps, 1);

    final node = tester.getSemantics(swatchFinder);
    expect(node.label, 'Blue');
    expect(node.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('the picker recolors its swatches when the color style changes', (
    tester,
  ) async {
    settings.theme.setUseSystemColor(false);
    await pumpThemingPage(tester);

    PaletteSwatchPainter painterIn(ThemePalette palette) =>
        _painterOf(tester, swatch(palette));
    final neutral = scheme(palette: ThemePalette.blue);
    expect(painterIn(ThemePalette.blue).scheme, neutral);

    await tester.tap(find.text('Color style'));
    await tester.pumpAndSettle();
    expect(find.byType(M3EMenuPanel), findsOneWidget);
    await tester.tap(find.text('Vibrant').last);
    await tester.pumpAndSettle();
    expect(settings.theme.variant.value, M3EColorVariant.vibrant);

    final vibrant = scheme(
      palette: ThemePalette.blue,
      variant: M3EColorVariant.vibrant,
    );
    expect(painterIn(ThemePalette.blue).scheme, vibrant);

    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final dark = scheme(
      brightness: Brightness.dark,
      mode: ThemePreference.dark,
      palette: ThemePalette.blue,
      variant: M3EColorVariant.vibrant,
    );
    expect(painterIn(ThemePalette.blue).scheme, dark);
  });
}

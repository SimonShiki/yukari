import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/pages/settings/theming/palette_picker.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/autostart.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';

import '../router_support.dart';
import '../theming_test_support.dart';

/// One swatch, read back from its own raster so the painted pixels are
/// asserted, not just the widget fields.
class SwatchRaster {
  SwatchRaster(this._boundary);

  final GlobalKey _boundary;
  ui.Image? _image;
  ByteData? _bytes;
  int _scale = 4;

  /// Rasterized above 1x so the ring and the bold check have whole interior
  /// pixels; 1x is used to see the anti-aliased edge pixels themselves.
  Future<void> read(WidgetTester tester, {int scale = 4}) async {
    _scale = scale;
    await tester.runAsync(() async {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      _image = await render.toImage(pixelRatio: _scale.toDouble());
      _bytes = await _image!.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
  }

  int get scale => _scale;
  int get width => _image!.width;
  int get height => _image!.height;

  /// The color of the rasterized pixel at (x, y).
  Color pixel(int x, int y) {
    final data = _bytes!.buffer.asUint8List();
    final index = (y * _image!.width + x) * 4;
    return Color.fromARGB(
      data[index + 3],
      data[index],
      data[index + 1],
      data[index + 2],
    );
  }

  /// The color of the pixel covering the logical point (x, y).
  Color at(int x, int y) => pixel((x * _scale).floor(), (y * _scale).floor());

  /// How many rasterized pixels are exactly [color].
  int count(Color color) {
    final target = color.toARGB32();
    final data = _bytes!.buffer.asUint8List();
    var total = 0;
    for (var i = 0; i + 3 < data.length; i += 4) {
      final argb =
          (data[i + 3] << 24) |
          (data[i] << 16) |
          (data[i + 1] << 8) |
          data[i + 2];
      if (argb == target) total++;
    }
    return total;
  }
}

/// Pumps a lone swatch and returns its raster and tap log.
Future<({SwatchRaster raster, List<bool> taps})> pumpSwatch(
  WidgetTester tester, {
  required ColorScheme scheme,
  bool selected = false,
  int scale = 4,
}) async {
  final boundary = GlobalKey();
  final taps = <bool>[];
  await pumpApp(
    tester,
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: boundary,
          child: PaletteSwatch(
            palette: ThemePalette.blue,
            scheme: scheme,
            label: 'Blue',
            selected: selected,
            onTap: () => taps.add(true),
          ),
        ),
      ),
    ),
    theme: appTheme(),
  );
  final raster = SwatchRaster(boundary);
  await raster.read(tester, scale: scale);
  return (raster: raster, taps: taps);
}

/// The painter drawing the swatch under [parent].
PaletteSwatchPainter painterOf(WidgetTester tester, Finder parent) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: parent,
                matching: find.byKey(PaletteSwatch.paintKey),
              ),
            )
            .painter!
        as PaletteSwatchPainter;

/// The first contiguous run of pixels on physical row [y] whose colors match.
({int start, int end}) _runOnRow(
  SwatchRaster raster,
  int y,
  bool Function(Color color) matches, {
  int from = 0,
  int? to,
}) {
  int? start;
  for (var x = from; x < (to ?? raster.width); x++) {
    if (matches(raster.pixel(x, y))) {
      start ??= x;
    } else if (start != null) {
      return (start: start, end: x - 1);
    }
  }
  if (start == null) throw StateError('no matching pixels on row $y');
  return (start: start, end: raster.width - 1);
}

/// The first and last pixel on physical row [y] whose colors match.
({int first, int last}) _boundsOnRow(
  SwatchRaster raster,
  int y,
  bool Function(Color color) matches,
) {
  int? first;
  int? last;
  for (var x = 0; x < raster.width; x++) {
    if (!matches(raster.pixel(x, y))) continue;
    first ??= x;
    last = x;
  }
  if (first == null || last == null) {
    throw StateError('no matching pixels on row $y');
  }
  return (first: first, last: last);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: const UnsupportedAutostart());
    settings.theme.setVariant(M3EColorVariant.neutral);
  });

  testWidgets('an unselected swatch paints the tile, ball halves and dot', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final blue = scheme(palette: ThemePalette.blue);
    final (:raster, :taps) = await pumpSwatch(tester, scheme: blue);
    final swatchFinder = find.byType(PaletteSwatch);

    final painter = painterOf(tester, swatchFinder);
    expect(painter.scheme, blue);
    expect(painter.selected, isFalse);
    expect(tester.getSize(swatchFinder), const Size(72, 72));
    expect(
      tester.getSize(find.byKey(PaletteSwatch.paintKey)),
      const Size(72, 72),
    );

    // The tile, one sample inside each ball half, and the center dot.
    expect(raster.at(36, 6), blue.surfaceContainer);
    expect(raster.at(36, 15), blue.primaryContainer);
    expect(raster.at(36, 57), blue.tertiaryContainer);
    expect(raster.at(36, 36), blue.primary);
    // The rounded corner is outside the tile.
    expect(raster.at(1, 1).toARGB32(), 0);
    // No ring and no check are painted.
    expect(raster.count(blue.onPrimary), 0);

    await tester.tap(find.byKey(PaletteSwatch.rippleKey));
    expect(taps, hasLength(1));

    final node = tester.getSemantics(swatchFinder);
    expect(node.label, 'Blue');
    expect(node.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('a selected swatch paints the ring, larger dot and bold check', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final blue = scheme(palette: ThemePalette.blue);
    final (:raster, taps: _) = await pumpSwatch(
      tester,
      scheme: blue,
      selected: true,
    );
    final selected = find.byType(PaletteSwatch);
    final painter = painterOf(tester, selected);
    expect(painter.selected, isTrue);
    expect(painter.scheme, blue);
    // The ambient theme is the app's own deep purple scheme.
    expect(appTheme().colorScheme.primary, isNot(blue.primary));

    // The tile is hidden: its former area is transparent.
    expect(raster.at(36, 6).toARGB32(), 0);
    expect(raster.at(6, 36).toARGB32(), 0);
    // The ring: 56 footprint with a 2 stroke at radius 27.
    expect(raster.at(36, 9), blue.primary);
    expect(raster.at(63, 36), blue.primary);
    expect(raster.at(36, 7).toARGB32(), 0);
    // The gap between the ring and the ball shows the page.
    expect(raster.at(36, 11).toARGB32(), 0);
    // The ball keeps its 48 size and role halves.
    expect(raster.at(36, 15), blue.primaryContainer);
    expect(raster.at(36, 57), blue.tertiaryContainer);
    // The 24 selected dot sits under a bold onPrimary check.
    expect(raster.at(36, 36), blue.primary);
    final check = raster.count(blue.onPrimary);
    expect(check, greaterThanOrEqualTo(300), reason: 'bold, not a slim glyph');
    expect(check, lessThanOrEqualTo(1500));

    final node = tester.getSemantics(selected);
    expect(node.label, 'Blue');
    expect(node.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(node.flagsCollection.isButton, isTrue);

    // The check uses the swatch's own scheme, not the ambient theme's.
    final darkBlue = scheme(
      brightness: Brightness.dark,
      mode: ThemePreference.dark,
      palette: ThemePalette.blue,
    );
    expect(darkBlue.onPrimary, isNot(appTheme().colorScheme.onPrimary));
    final dark = await pumpSwatch(tester, scheme: darkBlue, selected: true);
    expect(dark.raster.count(darkBlue.onPrimary), greaterThanOrEqualTo(300));
    expect(dark.raster.count(appTheme().colorScheme.onPrimary), 0);
    semantics.dispose();
  });

  testWidgets('the ripple layer sits above the painted swatch', (tester) async {
    final blue = scheme(palette: ThemePalette.blue);
    await pumpSwatch(tester, scheme: blue);
    final ripple = find.byKey(PaletteSwatch.rippleKey);

    expect(tester.getSize(ripple), const Size(72, 72));
    expect(tester.widget<Material>(ripple).type, MaterialType.transparency);
    final ink = tester.widget<InkWell>(
      find.descendant(of: ripple, matching: find.byType(InkWell)),
    );
    expect(ink.onTap, isNotNull);
    expect(
      ink.customBorder,
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

    // The ripple is the topmost layer of the swatch's stack.
    final stack = tester.widget<Stack>(
      find.ancestor(of: ripple, matching: find.byType(Stack)).first,
    );
    expect(
      (stack.children.last as Positioned).child.key,
      PaletteSwatch.rippleKey,
    );
  });

  testWidgets('the painted edges blend, so the shapes are anti-aliased', (
    tester,
  ) async {
    final blue = scheme(palette: ThemePalette.blue);

    // A 1x raster of the unselected swatch: crossing the upper ball edge, some
    // pixel must fade between the ball and the tile instead of snapping to
    // either solid color.
    final plain = await pumpSwatch(tester, scheme: blue, scale: 1);
    var ballFaded = false;
    for (var x = 10; x < 62; x++) {
      final color = plain.raster.pixel(x, 24);
      if (color != blue.primaryContainer && color != blue.surfaceContainer) {
        ballFaded = true;
        break;
      }
    }
    expect(ballFaded, isTrue, reason: 'the ball edge is not anti-aliased');

    // The selected ring is drawn over the transparent page: its edge must fade
    // between the primary stroke and nothing.
    final ring = await pumpSwatch(
      tester,
      scheme: blue,
      selected: true,
      scale: 1,
    );
    var ringFaded = false;
    for (var x = 4; x < 12; x++) {
      final color = ring.raster.pixel(x, 36);
      if (color.toARGB32() != 0 && color != blue.primary) {
        ringFaded = true;
        break;
      }
    }
    expect(ringFaded, isTrue, reason: 'the ring edge is not anti-aliased');
  });

  testWidgets('the painted shapes keep their component dimensions', (
    tester,
  ) async {
    final blue = scheme(palette: ThemePalette.blue);
    final plain = await pumpSwatch(tester, scheme: blue);
    final row = 36 * plain.raster.scale;

    // The unselected ball is 48dp: its lower half spans 48dp on the center row.
    final ball = _boundsOnRow(
      plain.raster,
      row,
      (color) => color == blue.tertiaryContainer,
    );
    expect((ball.last - ball.first + 1) / plain.raster.scale, closeTo(48, 1));

    // The unselected center dot is 20dp.
    final normalDot = _boundsOnRow(
      plain.raster,
      row,
      (color) => color == blue.primary,
    );
    expect(
      (normalDot.last - normalDot.first + 1) / plain.raster.scale,
      closeTo(20, 1),
    );

    final ring = await pumpSwatch(tester, scheme: blue, selected: true);
    final ringRow = 36 * ring.raster.scale;
    final selectedBall = _boundsOnRow(
      ring.raster,
      ringRow,
      (color) => color == blue.tertiaryContainer,
    );
    expect(
      (selectedBall.last - selectedBall.first + 1) / ring.raster.scale,
      closeTo(48, 1),
    );

    // The selected ring spans 56dp and its stroke is 2dp wide.
    final footprint = _boundsOnRow(
      ring.raster,
      ringRow,
      (color) => color.toARGB32() != 0,
    );
    expect(
      (footprint.last - footprint.first + 1) / ring.raster.scale,
      closeTo(56, 1),
    );
    final stroke = _runOnRow(
      ring.raster,
      ringRow,
      (color) => color.toARGB32() != 0,
    );
    expect(
      (stroke.end - stroke.start + 1) / ring.raster.scale,
      inInclusiveRange(1.5, 3),
    );

    // The selected center dot is 24dp, measured around the check.
    final center = 36 * ring.raster.scale;
    var left = center;
    while (left > 0 &&
        ring.raster.pixel(left, ringRow) != blue.tertiaryContainer) {
      left--;
    }
    var right = center;
    while (right < ring.raster.width - 1 &&
        ring.raster.pixel(right, ringRow) != blue.tertiaryContainer) {
      right++;
    }
    expect((right - left - 1) / ring.raster.scale, closeTo(24, 1));
  });

  testWidgets('the picker recolors its swatches when the color style changes', (
    tester,
  ) async {
    settings.theme.setUseSystemColor(false);
    await pumpThemingPage(tester);

    PaletteSwatchPainter painterIn(ThemePalette palette) =>
        painterOf(tester, swatch(palette));
    final neutral = scheme(palette: ThemePalette.blue);
    expect(painterIn(ThemePalette.blue).scheme, neutral);

    // Change the style through the row's menu, as the user would.
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
    final vibrantPainter = painterIn(ThemePalette.blue);
    expect(vibrantPainter.scheme, vibrant);
    expect(vibrant.primaryContainer, isNot(neutral.primaryContainer));

    // The row follows the appearance too, not just the variant.
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

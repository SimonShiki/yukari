import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/theming_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';

// KernelSU geometry, in logical pixels: 72 slot, 20 tile radius, 48 ball,
// 20/24 dot, 56 ring with 2 stroke, 16 bold check with 2.6 stroke.
const _slot = 72.0;
const _tileRadius = 20.0;
const _gap = 16.0;

/// The color scheme presets: one anti-aliased swatch per [ThemePalette].
class PalettePicker extends StatelessWidget {
  const PalettePicker({super.key, required this.controller});

  final ThemingController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final selected = controller.palette.value;
      final brightness = controller.brightnessFor(
        MediaQuery.platformBrightnessOf(context),
      );
      // Generated here so the row tracks the variant and mode too; inside the
      // item builder those signal reads would not be subscribed.
      final schemes = {
        for (final palette in ThemePalette.values)
          palette: controller.schemeForPalette(palette, brightness),
      };
      return SizedBox(
        height: _slot,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final n = ThemePalette.values.length;
            final rowWidth = n * _slot + (n - 1) * _gap;
            final padding = constraints.maxWidth >= rowWidth
                ? (constraints.maxWidth - rowWidth) / 2
                : _gap;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              itemCount: ThemePalette.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, index) {
                final palette = ThemePalette.values[index];
                return PaletteSwatch(
                  palette: palette,
                  scheme: schemes[palette]!,
                  label: _label(l10n, palette),
                  selected: palette == selected,
                  onTap: () => controller.selectPalette(palette),
                );
              },
            );
          },
        ),
      );
    },
  );
}

String _label(AppLocalizations l10n, ThemePalette palette) => switch (palette) {
  ThemePalette.deepPurple => l10n.themingPaletteDeepPurple,
  ThemePalette.blue => l10n.themingPaletteBlue,
  ThemePalette.teal => l10n.themingPaletteTeal,
  ThemePalette.green => l10n.themingPaletteGreen,
  ThemePalette.amber => l10n.themingPaletteAmber,
  ThemePalette.orange => l10n.themingPaletteOrange,
  ThemePalette.pink => l10n.themingPalettePink,
  ThemePalette.red => l10n.themingPaletteRed,
};

/// One preset: its scheme's ball on its surfaceContainer tile; selected swaps
/// the tile for a ring and a bold check.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({
    super.key,
    required this.palette,
    required this.scheme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final ColorScheme scheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The painted content, and the transparent ripple layer above it.
  static const paintKey = Key('palette-swatch-paint');
  static const rippleKey = Key('palette-swatch-ripple');

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: _slot,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: paintKey,
                painter: PaletteSwatchPainter(
                  scheme: scheme,
                  selected: selected,
                ),
              ),
            ),
            // Transparent and above the paint, so the splash covers the tile
            // and the ball, as a clickable Surface's ripple does.
            Positioned.fill(
              child: Material(
                key: rippleKey,
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_tileRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Paints one swatch anti-aliased: tile, ball arcs, dot, and ring + check.
class PaletteSwatchPainter extends CustomPainter {
  const PaletteSwatchPainter({required this.scheme, required this.selected});

  final ColorScheme scheme;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fill = Paint()
      ..isAntiAlias = true
      ..color = scheme.surfaceContainer;
    if (!selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_tileRadius),
        ),
        fill,
      );
    }
    final ball = Rect.fromCircle(center: center, radius: 24);
    canvas
      ..drawArc(
        ball,
        math.pi,
        math.pi,
        true,
        fill..color = scheme.primaryContainer,
      )
      ..drawArc(ball, 0, math.pi, true, fill..color = scheme.tertiaryContainer);
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2
      ..color = scheme.primary;

    if (selected) canvas.drawCircle(center, 27, stroke);
    canvas.drawCircle(center, selected ? 12 : 10, fill..color = scheme.primary);
    if (selected) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 6.5, center.dy + 0.5)
          ..lineTo(center.dx - 2, center.dy + 4.5)
          ..lineTo(center.dx + 6.5, center.dy - 4.5),
        stroke
          ..strokeWidth = 2.6
          ..color = scheme.onPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(PaletteSwatchPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.selected != selected;
}

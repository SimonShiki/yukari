import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// Width and height of one block cell, its gap included.
const double _cellExtent = 18;

/// The space kept between a cell's painted square and its slot.
const double _cellGap = 2;

/// The color of one block cell in the status picture.
///
/// `1` is a decoded block, a degree above 1 is a block some received frame
/// covers but the decoder has not solved yet, and `0` is a block nothing is
/// known about.
Color blockCellColor(int status, ColorScheme colors) => switch (status) {
  1 => colors.primary,
  > 1 => colors.tertiaryContainer,
  _ => colors.surfaceContainerHighest,
};

/// A picture of the receiver's progress: one cell per block, colored by the
/// status the fountain decoder reports for it.
///
/// It is a single [CustomPaint] on purpose — a transfer can carry hundreds of
/// blocks, and one widget per block would build and lay out that many boxes on
/// every scan. When a scan decodes new blocks their cells pulse once for
/// [_pulseDuration]; the painter repaints through that animation only, so an
/// idle grid costs nothing.
class BlockGrid extends StatefulWidget {
  /// Creates a grid for [status].
  const BlockGrid({super.key, required this.status, this.semanticLabel});

  /// Per-block status: `1` decoded, the pending degree, or `0` unknown.
  final List<int> status;

  /// The spoken description of the whole grid, built by the page from l10n; the
  /// painter itself is decorative.
  final String? semanticLabel;

  @override
  State<BlockGrid> createState() => _BlockGridState();
}

class _BlockGridState extends State<BlockGrid>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 260);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  Set<int> _pulsing = const <int>{};

  @override
  void didUpdateWidget(BlockGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.status, widget.status)) return;

    final newlyDecoded = <int>{
      for (var index = 0; index < widget.status.length; index++)
        if (widget.status[index] == 1 &&
            (index >= oldWidget.status.length || oldWidget.status[index] != 1))
          index,
    };
    _pulsing = newlyDecoded;
    if (newlyDecoded.isNotEmpty) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(
            widget.status.length,
            constraints.maxWidth,
          );
          final rows = columns == 0
              ? 0
              : (widget.status.length / columns).ceil();
          return SizedBox(
            height: rows * _cellExtent,
            child: CustomPaint(
              painter: _BlockGridPainter(
                status: widget.status,
                colors: colors,
                columns: columns,
                pulsing: _pulsing,
                pulse: _pulse,
              ),
            ),
          );
        },
      ),
    );
  }

  /// How many cells fit on one row of [width].
  static int _columnsFor(int count, double width) {
    if (count == 0 || !width.isFinite || width <= 0) return 0;
    final fitting = (width / _cellExtent).floor();
    return fitting.clamp(1, count);
  }
}

/// Paints every cell of a [BlockGrid] in one pass.
class _BlockGridPainter extends CustomPainter {
  _BlockGridPainter({
    required this.status,
    required this.colors,
    required this.columns,
    required this.pulsing,
    required this.pulse,
  }) : super(repaint: pulse);

  final List<int> status;
  final ColorScheme colors;
  final int columns;

  /// Cells that became decoded on the last status change, and pulse for it.
  final Set<int> pulsing;

  /// The pulse progress, 0 to 1; the cells grow and settle.
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (columns <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = Radius.circular((_cellExtent - _cellGap * 2) / 2);
    // The pulse peaks halfway through and settles at the end.
    final growing = 1 - (2 * pulse.value - 1).abs();

    for (var index = 0; index < status.length; index++) {
      final slot = Rect.fromLTWH(
        (index % columns) * _cellExtent,
        (index ~/ columns) * _cellExtent,
        _cellExtent,
        _cellExtent,
      );
      final square = slot.deflate(_cellGap);
      final scale = pulsing.contains(index) ? 1 + 0.35 * growing : 1.0;
      final rect = Rect.fromCenter(
        center: square.center,
        width: square.width * scale,
        height: square.height * scale,
      );
      paint.color = blockCellColor(status[index], colors);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(_BlockGridPainter oldDelegate) =>
      columns != oldDelegate.columns ||
      !listEquals(status, oldDelegate.status) ||
      pulsing != oldDelegate.pulsing ||
      colors.primary != oldDelegate.colors.primary ||
      colors.tertiaryContainer != oldDelegate.colors.tertiaryContainer ||
      colors.surfaceContainerHighest !=
          oldDelegate.colors.surfaceContainerHighest;
}

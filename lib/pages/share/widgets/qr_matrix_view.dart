import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Draws a QR module matrix as crisp, integer-sized squares.
///
/// The matrix is painted once as a [ui.Vertices] buffer, never as widgets or
/// per-module draws: the sender replaces the code several times a second while
/// streaming, so the paint path must stay allocation-light.
///
/// A qrs matrix already carries its four-module quiet zone, so this view adds
/// none of its own: a second border would only shrink the modules. The white
/// surface around it provides the physical margin a camera needs.
///
/// The code always draws black on white, in both themes: a camera needs that
/// contrast, so the view never takes the theme's colours.
class QrMatrixView extends StatelessWidget {
  const QrMatrixView({super.key, required this.matrix});

  /// Square module matrix, row-major; `true` is a dark module.
  final List<List<bool>> matrix;

  @override
  Widget build(BuildContext context) {
    if (matrix.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = matrix.length;
        final available = _shortestSide(constraints);
        // An integer module size keeps the module edges on pixel boundaries.
        final moduleSize = available.isFinite && available >= total
            ? (available / total).floorToDouble().clamp(1.0, 64.0)
            : 1.0;
        final size = moduleSize * total;
        final canvas = SizedBox(
          width: size,
          height: size,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _QrMatrixPainter(
                matrix: matrix,
                modules: _buildModuleVertices(matrix, moduleSize),
                moduleSize: moduleSize,
              ),
            ),
          ),
        );
        // Only shrink when the parent cannot fit one pixel per module.
        return available.isFinite && size > available
            ? FittedBox(fit: BoxFit.contain, child: canvas)
            : Center(child: canvas);
      },
    );
  }
}

/// The side of the tightest square the layout can give this widget.
double _shortestSide(BoxConstraints constraints) {
  final width = constraints.maxWidth;
  final height = constraints.maxHeight;
  if (!width.isFinite) return height;
  if (!height.isFinite) return width;
  return width < height ? width : height;
}

/// Packs every horizontal run of dark modules into one quad (two triangles),
/// so the whole code becomes a single [ui.Vertices] buffer.
///
/// Coordinates are `n * moduleSize`, and the caller guarantees integer logical
/// pixels, so module edges land exactly on pixel boundaries. Returns `null` for
/// an all-white matrix, which needs no vertex draw at all.
ui.Vertices? _buildModuleVertices(List<List<bool>> matrix, double moduleSize) {
  // Count the dark runs first so the buffer is allocated exactly once: no
  // growth and no per-frame garbage beyond the buffer itself.
  var runs = 0;
  for (final row in matrix) {
    for (var x = 0; x < row.length;) {
      if (!row[x]) {
        x += 1;
        continue;
      }
      runs += 1;
      while (x < row.length && row[x]) {
        x += 1;
      }
    }
  }
  if (runs == 0) return null;

  // Six vertices (two triangles) per run, two floats per vertex.
  final positions = Float32List(runs * 12);
  var i = 0;
  for (var y = 0; y < matrix.length; y++) {
    final row = matrix[y];
    final top = y * moduleSize;
    final bottom = top + moduleSize;

    for (var x = 0; x < row.length;) {
      if (!row[x]) {
        x += 1;
        continue;
      }
      var end = x + 1;
      while (end < row.length && row[end]) {
        end += 1;
      }
      final left = x * moduleSize;
      final right = end * moduleSize;

      // Top-left, top-right, bottom-right / top-left, bottom-right, bottom-left.
      positions[i++] = left;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = bottom;

      positions[i++] = left;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = bottom;
      positions[i++] = left;
      positions[i++] = bottom;

      x = end;
    }
  }

  return ui.Vertices.raw(ui.VertexMode.triangles, positions);
}

class _QrMatrixPainter extends CustomPainter {
  const _QrMatrixPainter({
    required this.matrix,
    required this.modules,
    required this.moduleSize,
  });

  final List<List<bool>> matrix;

  /// The dark modules as one vertex buffer, or `null` when there are none.
  final ui.Vertices? modules;

  /// The size the [modules] were built at, so a resize repaints.
  final double moduleSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final modules = this.modules;
    if (modules == null) return;

    // `Paint.color` is the colour of the triangles when the vertices carry no
    // per-vertex colours; anti-aliasing would only blur the module edges.
    canvas.drawVertices(
      modules,
      ui.BlendMode.srcOver,
      Paint()
        ..color = Colors.black
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_QrMatrixPainter oldDelegate) =>
      oldDelegate.matrix != matrix || oldDelegate.moduleSize != moduleSize;
}

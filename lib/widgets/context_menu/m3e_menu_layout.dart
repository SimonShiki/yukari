import 'package:material_ui/material_ui.dart';

/// Places the menu below [origin], flipping above it or clamping it to stay
/// within the safe area.
class M3EMenuLayout extends SingleChildLayoutDelegate {
  M3EMenuLayout(this.origin, this.padding);

  final Rect origin;
  final EdgeInsets padding;
  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        (padding + const EdgeInsets.all(_margin)).deflateSize(
          constraints.biggest,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = padding.deflateRect(Offset.zero & size).deflate(_margin);
    var x = origin.isEmpty ? origin.left : origin.right - childSize.width;
    var y = origin.bottom;
    if (y + childSize.height > bounds.bottom &&
        origin.top - childSize.height >= bounds.top) {
      y = origin.top - childSize.height;
    }
    x = x.clamp(bounds.left, bounds.right - childSize.width);
    y = y.clamp(bounds.top, bounds.bottom - childSize.height);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(M3EMenuLayout old) =>
      origin != old.origin || padding != old.padding;
}

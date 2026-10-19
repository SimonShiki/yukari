import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The container: the page, clipped to bounds that grow from [origin] to the
/// whole window.
///
/// The page keeps its window layout and is scaled as one piece, so its content
/// is cropped like a photo rather than squashed flat.
class DetailContainer extends StatelessWidget {
  const DetailContainer({
    super.key,
    required this.origin,
    required this.openness,
    required this.child,
  });

  /// The visible bounds of the growing container.
  static const Key containerKey = ValueKey<String>('network-detail-container');

  final Rect origin;

  /// How far the page is out of the card: zero at the card, one over the whole
  /// window.
  final double openness;

  final Widget child;

  /// The corner the page shrinks into: m3e_core draws the rows' outer corners
  /// with a radius of 24.
  static const double _cornerRadius = 24;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final window = Offset.zero & constraints.biggest;
      // One uniform scale, chosen so the page covers the container: a card is
      // much wider than it is tall, so the page is cropped to it rather than
      // stretched.
      final start = math.max(
        origin.width / window.width,
        origin.height / window.height,
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: Rect.lerp(origin, window, openness)!,
            child: ClipRRect(
              key: containerKey,
              borderRadius: BorderRadius.circular(
                _cornerRadius * (1 - openness),
              ),
              child: Opacity(
                // The page fades in as it leaves the card, so the card's own
                // fill is what shows at the small end instead of the page's
                // background over it.
                opacity: openness.clamp(0, 1),
                child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: window.width,
                maxHeight: window.height,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: start + (1 - start) * openness,
                    child: SizedBox(
                      width: window.width,
                      height: window.height,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The fallback for a route opened without a card: the page dissolves in over
/// the window.
class DetailDissolve extends StatelessWidget {
  const DetailDissolve({super.key, required this.openness, required this.child});

  final double openness;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: openness.clamp(0, 1),
    child: Transform.scale(scale: 0.9 + 0.1 * openness, child: child),
  );
}

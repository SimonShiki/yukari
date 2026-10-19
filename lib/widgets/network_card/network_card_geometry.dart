import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

/// The rect of the last card pressed, in the navigator's own coordinates.
///
/// A card reports it as the press happens, and the networks page hands it to
/// the route it pushes, so the route's transition grows out of that card.
final Signal<Rect?> networkCardOrigin = signal(null);

/// Takes the rect of the last card pressed, leaving nothing behind for the next
/// navigation to pick up.
Rect? takeNetworkCardOrigin() {
  final origin = networkCardOrigin.value;
  networkCardOrigin.value = null;
  return origin;
}

/// Reports where the card it wraps sits, on the pointer press that opens it.
///
/// The rect has to be read as the tap happens: the list may have scrolled since
/// the card was built, and the route's transition starts from it.
class NetworkCardGeometry extends StatelessWidget {
  const NetworkCardGeometry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => networkCardOrigin.value = _rectOf(context),
    child: child,
  );

  /// [context]'s box, measured from the navigator the route will be pushed on:
  /// the transition draws in that navigator's coordinate space.
  static Rect? _rectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final navigator = Navigator.of(context, rootNavigator: false);
    final origin = box.localToGlobal(
      Offset.zero,
      ancestor: navigator.context.findRenderObject(),
    );
    return origin & box.size;
  }
}

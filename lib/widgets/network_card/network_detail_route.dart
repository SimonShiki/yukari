import 'package:material_ui/material_ui.dart';

import 'network_detail_transition.dart';
import 'predictive_back_gesture_detector.dart';

/// The route a network's detail page is pushed as, so its own animation drives
/// the container transform from the card instead of the theme's transition.
class NetworkDetailRoute extends PageRoute<void> {
  NetworkDetailRoute({
    required this.origin,
    required this.builder,
    super.settings,
  });

  /// The card's rect the page grows out of and shrinks back into, or null for
  /// a route opened without one, as a deep link is.
  final Rect? origin;

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => NetworkDetailTransition.settleDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => PredictiveBackGestureDetector(
    route: this,
    builder: (context, gesture) => NetworkDetailTransition(
      animation: animation,
      gesture: gesture,
      origin: origin,
      child: child,
    ),
  );
}

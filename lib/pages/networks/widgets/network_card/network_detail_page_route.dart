import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../network_editor_page.dart';
import '../../network_instance_page.dart';
import 'network_detail_transition.dart';
import 'predictive_back_gesture_detector.dart';

/// The network instance page as a route whose own animation is the container
/// transform from the card the user tapped.
///
/// [GoRouterState.extra] carries that card's geometry; a route opened without
/// it, as a deep link is, dissolves in instead.
Page<void> networkInstanceRoute({
  required GoRouterState state,
  InstanceTab? initialTab,
}) => _detailRoute(
  state: state,
  builder: (context) => NetworkInstancePage(
    id: state.pathParameters['id']!,
    initialTab: initialTab,
  ),
);

/// The network editor page, opened from the same card and with the same
/// container transform. The page owns its own pop guard: it joins a predictive
/// back gesture while leaving loses nothing and asks first while it holds
/// invalid input.
Page<void> networkEditorRoute({required GoRouterState state}) => _detailRoute(
  state: state,
  builder: (context) => NetworkEditorPage(id: state.pathParameters['id']!),
);

Page<void> _detailRoute({
  required GoRouterState state,
  required WidgetBuilder builder,
}) => _DetailPage(
  key: state.pageKey,
  name: state.name,
  origin: state.extra is Rect ? state.extra! as Rect : null,
  builder: builder,
);

class _DetailPage extends Page<void> {
  const _DetailPage({
    required this.origin,
    required this.builder,
    super.key,
    super.name,
  });

  final Rect? origin;
  final WidgetBuilder builder;

  @override
  Route<void> createRoute(BuildContext context) =>
      NetworkDetailRoute(settings: this, origin: origin, builder: builder);
}

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

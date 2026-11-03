import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../pages/networks/network_editor_page.dart';
import '../../pages/networks/network_instance_page.dart';
import 'network_detail_route.dart';

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

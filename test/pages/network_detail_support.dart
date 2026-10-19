import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/network_instance_page.dart' show InstanceTab;
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/router.dart';
import 'package:yukari/signals/backend.dart' as backend_signals;
import 'package:yukari/widgets/network_card/network_card_geometry.dart';
import 'package:yukari/widgets/network_card/network_detail_page_route.dart';

import '../fake_backend.dart';
import '../widgets/network_detail_harness.dart';

export '../widgets/network_detail_harness.dart';

/// The window the real-router tests use.
///
/// The shell's navigation rail takes about 128 px, and the editor's advanced
/// tab overflows its `Row` below roughly 585 px of page width (pre-existing, not
/// addressed here), so the window is wider than a phone while staying below the
/// 840 breakpoint where the list keeps a detail pane and pushes nothing.
const realRouterWindow = Size(800, 800);

/// Points the app's own router at `/networks`, with the backend initialized as
/// `main` would, and cleans both up after each test.
void useRealDetailRouter() {
  setUpAll(() => backend_signals.initBackend('/data'));
  setUp(() {
    networkCardOrigin.value = null;
    appRouter.go('/networks');
  });
  tearDown(() {
    networkCardOrigin.value = null;
    appRouter.go('/');
  });
}

/// A backend that reports `alpha` as running unless told otherwise.
FakeBackend detailBackend({bool running = true}) => FakeBackend(
  collected: () => running
      ? {
          'alpha': {
            'running': true,
            'peers': <Object?>[],
            'events': <Object?>[],
          },
        }
      : {},
);

/// The app's detail routes, with the backend supplied by the test.
GoRouter detailRouter(NetworkPageController controller) => GoRouter(
  initialLocation: '/networks',
  routes: [
    GoRoute(
      path: '/networks',
      builder: (context, state) => NetworksPage(controller: controller),
      routes: [
        GoRoute(
          name: 'network-instance',
          path: 'instance/:id',
          pageBuilder: (context, state) => networkInstanceRoute(state: state),
        ),
        GoRoute(
          name: 'network-logs',
          path: 'instance/:id/logs',
          pageBuilder: (context, state) =>
              networkInstanceRoute(state: state, initialTab: InstanceTab.logs),
        ),
        GoRoute(
          name: 'network-edit',
          path: 'edit/:id',
          pageBuilder: (context, state) => networkEditorRoute(state: state),
        ),
      ],
    ),
  ],
);

/// Pumps the app that serves [router].
Future<void> pumpDetailRouter(WidgetTester tester, GoRouter router) =>
    tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

/// Pumps the list from a controller the test owns, backed by [detailBackend].
Future<NetworkPageController> pumpDetailList(
  WidgetTester tester, {
  bool running = true,
  Size size = const Size(400, 800),
}) async {
  useWindow(tester, size: size);
  late final GoRouter app;
  final controller = NetworkPageController(
    // The page's own navigation hands the pressed card's geometry to the route;
    // a controller supplied by the test goes through the same hand-off.
    navigate: (route, id) => id == null || route.startsWith('/')
        ? app.go(route)
        : app.goNamed(
            route,
            pathParameters: {'id': id},
            extra: takeNetworkCardOrigin(),
          ),
    showMessage: (_) {},
    confirmDelete: (_) async => true,
    showTunPermissionWarning: (_) async {},
    backend: detailBackend(running: running),
  );
  addTearDown(controller.dispose);
  controller.start();
  app = detailRouter(controller);
  await pumpDetailRouter(tester, app);
  await tester.pumpAndSettle();
  await controller.refresh();
  await tester.pumpAndSettle();
  return controller;
}

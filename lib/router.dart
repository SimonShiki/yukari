import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'pages/about/about_page.dart';
import 'pages/bookmarks/bookmarks_page.dart';
import 'pages/home/home_page.dart';
import 'pages/networks/editor_exit_guard.dart';
import 'pages/networks/network_creator_page.dart';
import 'pages/networks/network_instance_page.dart';
import 'pages/networks/networks_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/theming_page.dart';
import 'pages/share/qr_share_receive_page.dart';
import 'pages/share/qr_share_send_page.dart';
import 'share/share_document.dart';
import 'share/share_routes.dart';
import 'signals/settings.dart';
import 'widgets/navigation/app_shell.dart';
import 'widgets/network_card/network_detail_page_route.dart';

/// The navigator above the shell, for routes that cover it full-screen.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute(
      builder: (context, state, navigationShell) => navigationShell,
      navigatorContainerBuilder: (context, navigationShell, children) {
        // Swiping switches top pages, so it is offered only while the branch
        // shows its top page; a nested page owns the drag inside the branch.
        final location = GoRouterState.of(context).uri.path;
        return AppShell(
          currentIndex: navigationShell.currentIndex,
          pages: children,
          transitions: settings.interface.pageTransitions,
          swipeEnabled: location == _topPageLocation(navigationShell),
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'about',
                  builder: (context, state) => const AboutPage(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/networks',
              builder: (context, state) => const NetworksPage(),
              onExit: (context, state) =>
                  confirmLeavingPage(context, state.pageKey),
              routes: [
                GoRoute(
                  name: 'network-instance',
                  path: 'instance/:id',
                  pageBuilder: (context, state) =>
                      networkInstanceRoute(state: state),
                ),
                GoRoute(
                  name: 'network-logs',
                  path: 'instance/:id/logs',
                  pageBuilder: (context, state) => networkInstanceRoute(
                    state: state,
                    initialTab: InstanceTab.logs,
                  ),
                ),
                GoRoute(
                  name: 'network-edit',
                  path: 'edit/:id',
                  pageBuilder: (context, state) =>
                      networkEditorRoute(state: state),
                ),
                GoRoute(
                  name: 'network-create',
                  path: 'create',
                  builder: (context, state) => const NetworkCreatorPage(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookmarks',
              builder: (context, state) => const BookmarksPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                // Above the shell, so the theming page covers the whole
                // window and a deep link opens it directly.
                GoRoute(
                  path: 'theming',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      const MaterialPage(child: ThemingPage()),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: shareSendRoutePattern,
      pageBuilder: (context, state) {
        final kind = ShareKind.values.asNameMap()[state.pathParameters['kind']];
        return MaterialPage(
          key: ValueKey<String>(state.uri.path),
          child: QrShareSendPage(
            kind: kind ?? ShareKind.node,
            ids: kind == null
                ? const <String>[]
                : shareSendIds(state.pathParameters['id']),
          ),
        );
      },
    ),
    GoRoute(
      path: shareReceivePath,
      pageBuilder: (context, state) => MaterialPage(
        key: ValueKey<String>(state.uri.path),
        child: const QrShareReceivePage(),
      ),
    ),
  ],
);

/// The location of the top page of the active branch.
String _topPageLocation(StatefulNavigationShell navigationShell) {
  final branch = navigationShell.route.branches[navigationShell.currentIndex];
  return branch.initialLocation ?? branch.defaultRoute!.path;
}

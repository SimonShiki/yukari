import 'package:go_router/go_router.dart';

import 'widgets/navigation/app_shell.dart';
import 'pages/home/home_page.dart';
import 'pages/networks/networks_page.dart';
import 'pages/networks/network_editor_page.dart';
import 'pages/networks/network_instance_page.dart';
import 'pages/networks/network_creator_page.dart';
import 'pages/networks/editor_exit_guard.dart';
import 'pages/bookmarks/bookmarks_page.dart';
import 'pages/settings/settings_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        // Determine which index based on current location
        final String location = state.uri.path;
        int currentIndex = 0;

        if (location.startsWith('/networks')) {
          currentIndex = 1;
        } else if (location.startsWith('/bookmarks')) {
          currentIndex = 2;
        } else if (location.startsWith('/settings')) {
          currentIndex = 3;
        }

        return AppShell(currentIndex: currentIndex, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: '/networks',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const NetworksPage()),
          onExit: (context, state) =>
              confirmLeavingPage(context, state.pageKey),
          routes: [
            GoRoute(
              name: 'network-instance',
              path: 'instance/:id',
              builder: (context, state) =>
                  NetworkInstancePage(id: state.pathParameters['id']!),
            ),
            GoRoute(
              name: 'network-logs',
              path: 'instance/:id/logs',
              builder: (context, state) => NetworkInstancePage(
                id: state.pathParameters['id']!,
                initialTab: InstanceTab.logs,
              ),
            ),
            GoRoute(
              name: 'network-edit',
              path: 'edit/:id',
              builder: (context, state) =>
                  NetworkEditorPage(id: state.pathParameters['id']!),
              onExit: (context, state) =>
                  confirmLeavingPage(context, state.pageKey),
            ),
            GoRoute(
              name: 'network-create',
              path: 'create',
              builder: (context, state) => const NetworkCreatorPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/bookmarks',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BookmarksPage()),
          routes: [],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsPage()),
          routes: [],
        ),
      ],
    ),
  ],
);

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/network_create_menu.dart';
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/widgets/navigation/app_shell.dart';
import 'package:yukari/widgets/snackbar/app_snackbar.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

/// The shell's pages never switch in these tests; transitions stay on.
final Signal<bool> _transitions = signal(true);

/// A page shaped like the bookmarks page: its own Scaffold with a FAB.
class _PageWithFab extends StatelessWidget {
  const _PageWithFab({required this.withFab});

  final bool withFab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page')),
    floatingActionButton: withFab
        ? FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add))
        : null,
    body: Center(
      child: FilledButton(
        onPressed: () => showAppSnackBar(context, 'Message'),
        child: const Text('show'),
      ),
    ),
  );
}

/// The shell's four pages, one per destination, with [page] at [index].
List<Widget> pagesAt(int index, Widget page) => [
  for (var slot = 0; slot < 4; slot++)
    if (slot == index) page else const SizedBox.shrink(),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    bool withFab = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: AppShell(
          currentIndex: 2,
          pages: pagesAt(2, _PageWithFab(withFab: withFab)),
          transitions: _transitions,
          onDestinationSelected: (_) {},
        ),
      ),
    );
  }

  /// The snackbar's visible surface, without the margin around it.
  Rect snackBarRect(WidgetTester tester) => tester.getRect(
    find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first,
  );

  testWidgets('floats above the FAB without moving it', (tester) async {
    await pump(tester, size: const Size(400, 780));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final navigation = tester.getRect(find.byType(NavigationBar));

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
      SnackBarBehavior.floating,
    );
    final bar = snackBarRect(tester);
    expect(bar.overlaps(fab), isFalse, reason: 'snackbar covers the FAB');
    expect(bar.bottom, lessThanOrEqualTo(fab.top));
    expect(tester.getRect(find.byType(FloatingActionButton)), fab);
    expect(
      bar.bottom,
      lessThan(navigation.top),
      reason: 'snackbar reaches into the navigation bar',
    );
    expect(bar.left, greaterThanOrEqualTo(16));
    expect(bar.right, lessThanOrEqualTo(400 - 16));
  });

  testWidgets('stays clear of the navigation rail and the wide screen', (
    tester,
  ) async {
    await pump(tester, size: const Size(1000, 800));
    final rail = tester.getRect(find.byType(NavigationRail));

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    final bar = snackBarRect(tester);
    expect(
      bar.left,
      greaterThanOrEqualTo(rail.right),
      reason: 'snackbar covers the navigation rail',
    );
    expect(bar.width, lessThanOrEqualTo(560));
  });

  testWidgets('keeps clear of the navigation bar without a FAB', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 780), withFab: false);
    final navigation = tester.getRect(find.byType(NavigationBar));

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(snackBarRect(tester).bottom, lessThanOrEqualTo(navigation.top - 16));
  });

  testWidgets('floats above the networks page create menu', (tester) async {
    await tester.runAsync(seedNetworks);
    tester.view.physicalSize = const Size(400, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = NetworkPageController(
      navigate: (_, _) {},
      showMessage: (_) {},
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: FakeBackend(maxTunInstances: 1),
    );
    addTearDown(controller.dispose);
    controller.setActive(true);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: AppShell(
          currentIndex: 1,
          pages: pagesAt(1, NetworksPage(controller: controller)),
          transitions: _transitions,
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sent from inside the page, as its controller would.
    showAppSnackBar(tester.element(find.byType(NetworkCreateMenu)), 'Message');
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byType(NetworkCreateMenu));
    final bar = snackBarRect(tester);
    expect(bar.overlaps(menu), isFalse, reason: 'snackbar covers the menu');
    expect(bar.bottom, lessThanOrEqualTo(menu.top));
  });

  testWidgets('shrinks out of the way after the display duration', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 780));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    final shown = snackBarRect(tester);

    // The display duration elapses, so the show animation starts reversing.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));

    // The surface is still there, collapsing towards the bottom edge.
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'the snackbar was removed without animating out',
    );
    final hiding = snackBarRect(tester);
    expect(
      hiding.height,
      lessThan(shown.height),
      reason: 'the height did not animate out',
    );
    expect(
      hiding.top,
      greaterThan(shown.top),
      reason: 'the surface did not move towards the edge',
    );
    expect(hiding.bottom, closeTo(shown.bottom, 0.1));

    // It is gone only once the reverse transition has finished.
    await tester.pump(const Duration(milliseconds: 125));
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'the reverse was cut short',
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}

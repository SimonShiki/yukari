import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/about/about_page.dart';
import 'package:yukari/pages/bookmarks/bookmarks_page.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/pages/settings/settings_page.dart';
import 'package:yukari/pages/settings/theming_page.dart';
import 'package:yukari/router.dart';
import 'package:yukari/signals/backend.dart' as backend_signals;
import 'package:yukari/signals/settings.dart';

import 'router_support.dart';
import 'theming_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    appRouter.go('/');
    settings.interface.setPageTransitions(true);
  });

  PageController pageController(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  final Matcher neverScrollable = isA<NeverScrollableScrollPhysics>();

  test('the root navigator key is the one above the shell', () {
    expect(
      identical(appRouter.routerDelegate.navigatorKey, rootNavigatorKey),
      isTrue,
    );
  });

  testWidgets('the About route deep-links into the home branch', (
    tester,
  ) async {
    // Applying the location before the first build keeps the home dashboard
    // (and its backend probing) out of the test.
    appRouter.go('/about');
    await pumpApp(tester, size: const Size(400, 780));

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selectedIndex(tester), 0);
    expect(pageController(tester).page, 0.0);
  });

  testWidgets('a top-page deep link selects its destination and page', (
    tester,
  ) async {
    appRouter.go('/bookmarks');
    await pumpApp(tester, size: const Size(400, 780));

    expect(find.byType(BookmarksPage), findsOneWidget);
    expect(selectedIndex(tester), 2);
    expect(pageController(tester).page, 2.0);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isNot(neverScrollable),
    );
  });

  testWidgets('a nested branch deep link keeps the branch page', (
    tester,
  ) async {
    appRouter.go('/networks/instance/lab');
    await pumpApp(tester, size: const Size(400, 780));

    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(selectedIndex(tester), 1);
    expect(pageController(tester).page, 1.0);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      neverScrollable,
    );

    // Disposing the tree cancels the page's refresh timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('swiping a top page switches the branch', (tester) async {
    appRouter.go('/networks');
    await pumpApp(tester, size: const Size(400, 780));
    expect(find.byType(NetworksPage), findsOneWidget);
    expect(pageController(tester).page, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-250, 0));
    await tester.pump();

    // Mid-gesture the viewport straddles the two pages: the switch animates.
    expect(pageController(tester).page, inExclusiveRange(1.0, 2.0));
    expect(selectedIndex(tester), 2);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pageController(tester).page, 2.0);
    expect(selectedIndex(tester), 2);
    expect(find.byType(BookmarksPage), findsOneWidget);
    expect(appRouter.state.uri.path, '/bookmarks');

    // A nested branch page keeps the swipe to itself.
    appRouter.go('/about');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(pageController(tester).page, 0.0);
    expect(selectedIndex(tester), 0);
    expect(find.byType(AboutPage), findsOneWidget);
    expect(appRouter.state.uri.path, '/about');
  });

  testWidgets('a wide window has no switch gesture and slides horizontally', (
    tester,
  ) async {
    appRouter.go('/networks');
    await pumpApp(tester, size: const Size(1000, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<PageView>(find.byType(PageView)).scrollDirection,
      Axis.horizontal,
    );
    expect(pageController(tester).page, 1.0);

    // Neither drag direction switches pages on the wide layout.
    await tester.drag(find.byType(PageView), const Offset(-450, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(pageController(tester).page, 1.0);
    expect(appRouter.state.uri.path, '/networks');

    // A rail destination tap still animates, horizontally.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Bookmarks'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pageController(tester).page, inExclusiveRange(1.0, 2.0));
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      2,
    );

    await tester.pumpAndSettle();
    expect(pageController(tester).page, 2.0);
    expect(find.byType(BookmarksPage), findsOneWidget);
    expect(appRouter.state.uri.path, '/bookmarks');
  });

  testWidgets('tapping a destination animates to its page', (tester) async {
    appRouter.go('/about');
    await pumpApp(tester, size: const Size(400, 780));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bookmarks'),
      ),
    );
    await tester.pump();
    expect(selectedIndex(tester), 2);

    await tester.pump(const Duration(milliseconds: 100));
    expect(pageController(tester).page, inExclusiveRange(0.0, 2.0));
    expect(find.byType(AboutPage, skipOffstage: false), findsOneWidget);

    await tester.pumpAndSettle();
    expect(pageController(tester).page, 2.0);
    expect(find.byType(BookmarksPage), findsOneWidget);

    // The home branch kept its stack: tapping Home restores /about.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(pageController(tester).page, 0.0);
    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('a programmatic top-page change animates', (tester) async {
    appRouter.go('/about');
    await pumpApp(tester, size: const Size(400, 780));

    appRouter.go('/bookmarks');
    await tester.pump();
    expect(selectedIndex(tester), 2);

    await tester.pump(const Duration(milliseconds: 100));
    expect(pageController(tester).page, inExclusiveRange(0.0, 2.0));

    await tester.pumpAndSettle();
    expect(pageController(tester).page, 2.0);
    expect(find.byType(BookmarksPage), findsOneWidget);
    expect(find.byType(AboutPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('the page transitions setting reaches the shell', (tester) async {
    // A branch root page, where swiping is allowed while transitions are on.
    appRouter.go('/bookmarks');
    await pumpApp(tester, size: const Size(400, 780));
    expect(settings.interface.pageTransitions.value, isTrue);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isNot(neverScrollable),
    );

    settings.interface.setPageTransitions(false);
    await tester.pump();
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      neverScrollable,
    );

    // A programmatic branch change jumps in a single frame.
    appRouter.go('/about');
    await tester.pump();
    expect(pageController(tester).page, 0.0);
    expect(selectedIndex(tester), 0);

    // So does a destination tap.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bookmarks'),
      ),
    );
    await tester.pump();
    expect(pageController(tester).page, 2.0);
    expect(selectedIndex(tester), 2);

    // Turning it back on restores the swipe and the slide.
    settings.interface.setPageTransitions(true);
    await tester.pump();
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isNot(neverScrollable),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pageController(tester).page, inExclusiveRange(0.0, 2.0));
    await tester.pumpAndSettle();
    expect(pageController(tester).page, 0.0);
    expect(find.byType(AboutPage), findsOneWidget);
  });

  group('theming routes', () {
    // The settings page reads the service control as it builds.
    setUpAll(() => backend_signals.initBackend('/data'));

    testWidgets('a deep link opens the theming page over the shell', (
      tester,
    ) async {
      expect(settings.theme.useSystemColor.value, isTrue);
      appRouter.go('/settings/theming');
      await pumpApp(tester, theme: appTheme());

      expect(find.byType(ThemingPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // The page itself can turn system colors off.
      expect(find.text('Use system color'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ThemingPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the settings row opens the page and back returns', (
      tester,
    ) async {
      appRouter.go('/settings');
      await pumpApp(tester, theme: appTheme());

      expect(find.text('Use system color'), findsNothing);

      // The Interface section sits below the fold on a phone-sized settings
      // page.
      await tester.ensureVisible(find.text('Theme settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme settings'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Use system color'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ThemingPage), findsNothing);
      expect(find.text('Use system color'), findsNothing);
      expect(find.text('Theme settings'), findsOneWidget);
    });
  });
}

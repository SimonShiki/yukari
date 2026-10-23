import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/about/about_page.dart';
import 'package:yukari/pages/bookmarks/bookmarks_page.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/pages/settings/settings_page.dart';
import 'package:yukari/pages/settings/theming_page.dart';
import 'package:yukari/pages/share/qr_share_receive_page.dart';
import 'package:yukari/pages/share/qr_share_send_page.dart';
import 'package:yukari/pages/share/widgets/qr_matrix_view.dart';
import 'package:yukari/router.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';
import 'package:yukari/signals/backend.dart' as backend_signals;
import 'package:yukari/signals/settings.dart';
import 'package:yukari_core/models/models.dart';

import 'bookmarks_fixture.dart';
import 'networks_fixture.dart';
import 'router_support.dart';
import 'theming_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final strings = lookupAppLocalizations(const Locale('en'));

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

  group('share routes', () {
    // `defaultTargetPlatform` is android under `flutter test`, so the receiver
    // would build the camera widget; this platform scans a picked image. The
    // override is reset before the test returns: the binding checks that no
    // foundation debug variable was left changed.
    Future<void> withoutCamera(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    final node = Node(
      id: 'peer1',
      url: Uri.parse('relay.example.com'),
      port: 11010,
      protocols: const [NodeProtocol.tcp],
    );

    testWidgets('a network share link streams the saved network', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedWith({
          'n1': Network()
            ..networkName = 'alpha'
            ..nodes = [node],
        }),
      );
      appRouter.go(shareSendPath(ShareKind.network, 'n1'));
      await pumpApp(tester, size: const Size(400, 800));

      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // The page owns a playing sender; unmounting disposes it and stops its
      // timer.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a bundle link opens the sender with every document', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedWith({
          'n1': Network()
            ..networkName = 'alpha'
            ..nodes = [node],
          'n2': Network()
            ..networkName = 'beta'
            ..nodes = [node],
        }),
      );
      appRouter.go(shareSendPaths(ShareKind.network, ['n1', 'n2']));
      await pumpApp(tester, size: const Size(400, 800));

      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text(strings.shareItems(2)), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a bundle link naming a target that is gone shares nothing', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedWith({
          'n1': Network()
            ..networkName = 'alpha'
            ..nodes = [node],
        }),
      );
      appRouter.go(shareSendPaths(ShareKind.network, ['n1', 'gone']));
      await pumpApp(tester, size: const Size(400, 800));

      expect(tester.takeException(), isNull);
      expect(find.text(strings.shareSendNetworkMissing), findsOneWidget);
      expect(find.byType(QrMatrixView), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a bookmark share link streams the saved bookmark', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedBookmarks([
          testBookmark('u1', name: 'Relay', host: 'relay.example.com'),
        ]),
      );
      appRouter.go(shareSendPath(ShareKind.node, 'u1'));
      await pumpApp(tester, size: const Size(400, 800));

      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text('relay.example.com:11010'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an unknown id or kind shows the missing state, no crash', (
      tester,
    ) async {
      await tester.runAsync(() => seedWith({}));
      await tester.runAsync(
        () => seedBookmarks([
          testBookmark('u1', name: 'Relay', host: 'relay.example.com'),
        ]),
      );
      appRouter.go(shareSendPath(ShareKind.network, 'gone'));
      await pumpApp(tester, size: const Size(400, 800));

      expect(tester.takeException(), isNull);
      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text(strings.shareSendNetworkMissing), findsOneWidget);

      appRouter.go(shareSendPath(ShareKind.node, 'gone'));
      await tester.pumpAndSettle();
      expect(find.text(strings.shareSendNodeMissing), findsOneWidget);

      // An unknown :kind reaches the same missing state instead of throwing in
      // the router.
      appRouter.go('/share/send/bogus/gone');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text(strings.shareSendNodeMissing), findsOneWidget);

      // A bogus kind with a real bookmark id is an invalid link too: it must
      // not stream the bookmark the id names.
      appRouter.go('/share/send/bogus/u1');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.text(strings.shareSendNodeMissing), findsOneWidget);
      expect(
        find.byType(QrMatrixView),
        findsNothing,
        reason: 'nothing streams',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the receive route covers the shell and back returns', (
      tester,
    ) async {
      await withoutCamera(() async {
        appRouter.go('/bookmarks');
        await pumpApp(tester, size: const Size(400, 800));
        expect(find.byType(BookmarksPage), findsOneWidget);

        appRouter.push<void>(shareReceivePath);
        // The receiver's indeterminate progress animates until the first
        // frame, so bounded frames settle the route without waiting for
        // stillness.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(QrShareReceivePage), findsOneWidget);
        expect(find.text(strings.shareReceiveTitle), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(QrShareReceivePage), findsNothing);
        expect(find.byType(BookmarksPage), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    testWidgets('the share sheet pushes the sender and back returns', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedBookmarks([
          testBookmark('u1', name: 'Alpha', host: 'relay.example.com'),
        ]),
      );
      appRouter.go('/bookmarks');
      await pumpApp(tester, size: const Size(400, 800));

      // The built-in shared nodes sit above the saved bookmark; searching
      // narrows the list to it.
      await tester.enterText(find.byType(SearchBar), 'Alpha');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options for Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show QR code'));
      await tester.pumpAndSettle();

      expect(find.byType(QrShareSendPage), findsOneWidget);
      expect(find.byType(BookmarksPage), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(QrShareSendPage), findsNothing);
      expect(find.byType(BookmarksPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

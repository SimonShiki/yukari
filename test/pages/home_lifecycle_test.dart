import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/home/home_page.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/utils/stun_probe.dart';
import 'package:yukari/widgets/navigation/top_page_view.dart';
import 'package:yukari_core/models/models.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';
import '../system/instance_info.dart';

void main() {
  late CountingBackend backend;
  late HomeController home;
  late GlobalKey<NavigatorState> homeNavigator;
  late GlobalKey<NavigatorState> otherNavigator;
  var probes = 0;
  var versions = 0;
  var received = 1000;

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(state.toString()),
      null,
    );
  }

  setUp(() {
    probes = versions = 0;
    received = 1000;
    backend = CountingBackend(
      collected: () => {
        'alpha': instanceInfo(peers: [instancePeer(rx: received)]),
      },
    );
    home = HomeController(
      backend: backend,
      refreshInterval: const Duration(seconds: 1),
      probe: () async {
        probes++;
        return const NatProbe(publicAddress: null, natType: NatType.unknown);
      },
      probeServiceVersion: () async {
        versions++;
        return 1;
      },
    );
    addTearDown(home.dispose);
    homeNavigator = GlobalKey<NavigatorState>();
    otherNavigator = GlobalKey<NavigatorState>();
  });

  Future<void> pumpShell(WidgetTester tester, int index) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopPageView(
          currentIndex: index,
          swipeEnabled: false,
          transitionsEnabled: false,
          onPageChanged: (_) {},
          pages: [
            Navigator(
              key: homeNavigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => HomePage(controller: home),
              ),
            ),
            Navigator(
              key: otherNavigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Other tab')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('inactive controllers stop polling and ignore saved changes', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    expect(backend.collects, 0);
    home.setActive(true);
    home.setActive(true);
    await tester.pump();
    expect(backend.collects, 1);
    expect(probes, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(backend.collects, 2);

    home.setActive(false);
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => saved.addNetwork('n3', Network()..networkName = 'gamma'),
    );
    expect(backend.collects, 2);
    expect(versions, 1);

    received = 100000;
    home.setActive(true);
    await tester.pump();
    expect(backend.collects, 3);
    expect(home.totalReceived.peek(), 100000);
    expect(home.receiveRate.peek(), 0);
    expect(home.savedCount.peek(), 3);
    expect(versions, 2);
    expect(probes, 1);
    home.setActive(false);
  });

  testWidgets('Home pauses across tabs, covered routes, and app background', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpShell(tester, 0);
    final first = backend.collects;
    await tester.pump(const Duration(seconds: 1));
    expect(backend.collects, first + 1);

    final pageState = tester.state(find.byType(HomePage));
    await pumpShell(tester, 1);
    final hidden = backend.collects;
    expect(pageState.mounted, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(backend.collects, hidden);

    await pumpShell(tester, 0);
    expect(backend.collects, hidden + 1);
    unawaited(
      homeNavigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final covered = backend.collects;
    await tester.pump(const Duration(seconds: 3));
    expect(backend.collects, covered);
    homeNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(backend.collects, covered + 1);

    addTearDown(() => lifecycle(tester, AppLifecycleState.resumed));
    await lifecycle(tester, AppLifecycleState.paused);
    final paused = backend.collects;
    await tester.pump(const Duration(seconds: 3));
    expect(backend.collects, paused);
    await lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(backend.collects, paused + 1);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('mounting in the background waits for the app to resume', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    addTearDown(() => lifecycle(tester, AppLifecycleState.resumed));
    await lifecycle(tester, AppLifecycleState.paused);
    await pumpShell(tester, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(backend.collects, 0);
    expect(probes, 0);

    await lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.collects, 1);
    expect(probes, 1);
  });
}

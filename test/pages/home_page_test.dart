import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/pages/home/home_page.dart';
import 'package:yukari/pages/home/widgets/address_card.dart';
import 'package:yukari/pages/home/widgets/dashboard_skeleton.dart';
import 'package:yukari/pages/home/widgets/nat_card.dart';
import 'package:yukari/pages/home/widgets/networks_card.dart';
import 'package:yukari/pages/home/widgets/traffic_card.dart';
import 'package:yukari/utils/stun_probe.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  Future<HomeController> pump(
    WidgetTester tester,
    Size size, {
    bool running = true,
    bool refresh = true,
  }) async {
    await tester.runAsync(seedNetworks);
    final info = jsonDecode(
      File('test/fixtures/collected_instance.json').readAsStringSync(),
    );
    final controller = HomeController(
      backend: FakeBackend(collected: () => running ? {'alpha': info} : {}),
      // Never answers when nothing should have loaded yet.
      probe: () => refresh
          ? Future.value(
              const NatProbe(
                publicAddress: '203.0.113.7',
                natType: NatType.portRestricted,
              ),
            )
          : Completer<NatProbe>().future,
      probeServiceVersion: () async => null,
      refreshInterval: const Duration(days: 1),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: HomePage(controller: controller),
      ),
    );
    if (refresh) {
      await tester.runAsync(controller.refresh);
      // Past the skeletons' cross-fade.
      await tester.pump(const Duration(seconds: 1));
    }
    return controller;
  }

  for (final size in [const Size(400, 1600), const Size(1000, 900)]) {
    testWidgets('shows running networks at ${size.width}', (tester) async {
      final controller = await pump(tester, size);

      expect(find.text('Running in app'), findsOneWidget);
      expect(find.text('EasyTier 2.7.0-1649ec00'), findsOneWidget);
      expect(find.text('1 of 2 running'), findsOneWidget);
      expect(find.text('Virtual IP'), findsOneWidget);
      expect(find.text('10.144.0.2'), findsOneWidget);
      expect(find.text('Symmetric'), findsOneWidget);
      expect(find.text('Hard P2P · often relayed'), findsOneWidget);
      expect(find.textContaining('/s'), findsOneWidget);
      // Every card is as tall as the others, so the rows stay even.
      final heights = {
        for (final type in [NetworksCard, AddressCard, NatCard, TrafficCard])
          tester.getSize(find.byType(type)).height,
      };
      expect(heights, hasLength(1));
      // Stops the refresh timer before the test checks for pending ones.
      controller.dispose();
    });
  }

  testWidgets('shows the public address while no network runs', (tester) async {
    final controller = await pump(
      tester,
      const Size(400, 1600),
      running: false,
    );

    expect(find.text('0 of 2 running'), findsOneWidget);
    expect(find.text('Public IP'), findsOneWidget);
    expect(find.text('203.0.113.7'), findsOneWidget);
    expect(find.text('Port restricted cone'), findsOneWidget);
    expect(find.text('Fair P2P · usually direct'), findsOneWidget);
    expect(find.text('No traffic'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('shows skeletons until the first refresh', (tester) async {
    final controller = await pump(
      tester,
      const Size(1000, 900),
      refresh: false,
    );

    expect(find.text('Running in app'), findsOneWidget);
    expect(find.byType(DashboardSkeleton), findsNWidgets(4));
    expect(find.text('0 of 2 running'), findsNothing);
    // As tall as the loaded cards, so that nothing moves when data comes.
    final heights = {
      for (final type in [NetworksCard, AddressCard, NatCard, TrafficCard])
        tester.getSize(find.byType(type)).height,
    };
    expect(heights, hasLength(1));
    controller.dispose();
  });
}

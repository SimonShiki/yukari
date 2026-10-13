import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:signals/signals.dart';
import 'package:yukari/signals/instance_logs.dart';
import 'package:yukari/widgets/peer_card/peer_card.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

List<String> _fixed() => _events;

String _peer(int n) =>
    '{"time":"2026-10-12T21:${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}+08:00","event":{"PeerAdded":$n}}';

const _events = [
  '{"time":"2026-10-12T21:21:43+08:00","event":{"ConnectError":["tcp://1.2.3.4:11010","v4","timeout"]}}',
  '{"time":"2026-10-12T21:21:42+08:00","event":{"PeerAdded":1269433021}}',
  '{"time":"2026-10-12T21:21:41+08:00","event":{"ListenerAdded":"tcp://0.0.0.0:11010"}}',
];

void main() {
  setUp(() async {
    await seedNetworks();
    clearInstanceLogs('n1');
  });

  Future<NetworkInstanceController> pump(
    WidgetTester tester, {
    Map<String, Object?>? collected,
    List<String> Function() events = _fixed,
    InstanceTab tab = InstanceTab.logs,
    Signal<InstanceTab>? tabSignal,
  }) async {
    final controller = NetworkInstanceController(
      id: 'n1',
      backend: FakeBackend(
        collected: () => {
          'alpha': collected ?? {'running': true, 'events': events()},
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: NetworkInstancePage(
          id: 'n1',
          initialTab: tab,
          tab: tabSignal,
          controller: controller,
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('opens on the requested tab with structured entries', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('Peer 1269433021 joined'), findsOneWidget);
    expect(find.text('Listening on tcp://0.0.0.0:11010'), findsOneWidget);
  });

  testWidgets('filters by category', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Errors 1'));
    await tester.pump();
    expect(find.textContaining('Cannot connect'), findsOneWidget);
    expect(find.text('Peer 1269433021 joined'), findsNothing);
  });

  testWidgets('wraps filters on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);

    for (final label in [
      'All 3',
      'Errors 1',
      'Peers 1',
      'Connections 1',
      'Listeners 1',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('expands an entry to show its details', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Peer 1269433021 joined'));
    await tester.pumpAndSettle();
    expect(find.text('PeerAdded'), findsOneWidget);
    expect(find.text('1269433021'), findsOneWidget);
  });

  testWidgets('shows an empty peers state', (tester) async {
    await pump(tester, tab: InstanceTab.peers);
    expect(find.text('No peers yet'), findsOneWidget);
  });

  testWidgets('lists this device first, then its peers', (tester) async {
    final collected = jsonDecode(
      File('test/fixtures/collected_instance.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final pair =
        (collected['peer_route_pairs'] as List<Object?>).single
            as Map<String, Object?>;
    final conn =
        ((pair['peer'] as Map<String, Object?>)['conns'] as List<Object?>)
                .single
            as Map<String, Object?>;
    conn['secure_auth_level'] = 'NetworkSecretConfirmed';
    conn['peer_identity_type'] = 'SharedNode';

    await pump(tester, collected: collected, tab: InstanceTab.peers);
    expect(find.text('This device'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('host-b')).dy,
      lessThan(tester.getTopLeft(find.text('host-a')).dy),
    );
    expect(find.text('P2P'), findsOneWidget);
    // Latency is the headline's status, beside the name.
    expect(
      tester.getCenter(find.text('0 ms')).dy,
      closeTo(tester.getCenter(find.text('host-a')).dy, 2),
    );
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(find.text('10.144.0.1'), findsOneWidget);
    // Every card has the same height, including our own.
    final cards = find.byType(PeerCard);
    expect(
      tester.getSize(cards.first).height,
      tester.getSize(cards.last).height,
    );

    // Tags are labeled, and explain themselves when tapped.
    expect(find.text('Shared node'), findsOneWidget);
    await tester.tap(find.text('Secret verified'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.textContaining('proved it knows the network secret'),
      findsOneWidget,
    );
  });

  testWidgets('switches tabs when asked to', (tester) async {
    final tab = signal(InstanceTab.peers);
    await pump(tester, tab: InstanceTab.peers, tabSignal: tab);
    expect(find.text('No peers yet'), findsOneWidget);

    tab.value = InstanceTab.logs;
    await tester.pumpAndSettle();
    expect(find.text('Peer 1269433021 joined'), findsOneWidget);

    // Switching back by hand is reflected, so asking for logs again works.
    await tester.tap(find.text('Peers'));
    await tester.pumpAndSettle();
    expect(tab.value, InstanceTab.peers);
    tab.value = InstanceTab.logs;
    await tester.pumpAndSettle();
    expect(find.text('Peer 1269433021 joined'), findsOneWidget);
  });

  group('with a long history', () {
    late List<String> events;
    var newest = 0;

    void arrive(int count, {bool varied = false}) {
      // EasyTier reports its 20 most recent events, newest first.
      for (var i = 0; i < count; i++) {
        ++newest;
        // Long errors wrap to two lines, so entry heights differ.
        events.insert(
          0,
          varied && newest.isOdd
              ? '{"time":"2026-10-12T21:00:00+08:00","event":{"ConnectError":'
                    '["tcp://192.168.100.100:11010","V4","$newest ${'connect timeout ' * 8}"]}}'
              : _peer(newest),
        );
      }
      events = events.take(20).toList();
    }

    setUp(() {
      newest = 0;
      events = [];
    });

    Future<NetworkInstanceController> pumpHistory(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        arrive(20);
        recordInstanceEvents('n1', events);
      }
      return pump(tester, events: () => events);
    }

    testWidgets('follows the newest entry while at the top', (tester) async {
      final controller = await pumpHistory(tester);
      arrive(2);
      await controller.refresh();
      await tester.pump();
      expect(find.text('Peer $newest joined'), findsOneWidget);
    });

    testWidgets('keeps the viewed entries still once scrolled', (tester) async {
      final controller = await pumpHistory(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final viewed = find.text('Peer ${newest - 6} joined');
      final before = tester.getTopLeft(viewed);

      arrive(3);
      await controller.refresh();
      await tester.pump();
      expect(tester.getTopLeft(viewed), before);
      expect(find.text('Peer $newest joined'), findsNothing);
    });

    testWidgets('offers a way back to the top', (tester) async {
      final controller = await pumpHistory(tester);
      final backToTop = find.byTooltip('Back to top');
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: backToTop, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      arrive(3);
      await controller.refresh();
      await tester.pump();

      await tester.tap(backToTop);
      await tester.pumpAndSettle();
      expect(find.text('Peer $newest joined'), findsOneWidget);
    });

    testWidgets('goes back to the very top when entries vary in height', (
      tester,
    ) async {
      final controller = await pumpHistory(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        arrive(20, varied: true);
        await controller.refresh();
        await tester.pump();
      }

      await tester.tap(find.byTooltip('Back to top'));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      expect(position.pixels, position.minScrollExtent);
      expect(find.text('Peer $newest joined'), findsOneWidget);
    });
  });
}

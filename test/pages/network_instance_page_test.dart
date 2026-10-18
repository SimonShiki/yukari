import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/log_entry.dart';
import 'package:yukari/widgets/log_entry/log_summary.dart';
import 'package:yukari/widgets/peer_card/peer_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/signals/instance_logs.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';
import 'network_test_support.dart';

void main() {
  useDeterministicCursor();

  const version = '{"time":"2024-01-01T00:00:03Z","event":"ConnectionError"}';
  const peer = '{"time":"2024-01-01T00:00:02Z","event":{"PeerAdded":"2"}}';
  const tun = '{"time":"2024-01-01T00:00:01Z","event":"TunDeviceError"}';
  const listener =
      '{"time":"2024-01-01T00:00:00Z","event":{"ListenerAdded":"tcp://0.0.0.0:11010"}}';

  Future<NetworkInstanceController> pumpInstance(
    WidgetTester tester, {
    InstanceTab initialTab = InstanceTab.peers,
    Signal<InstanceTab>? tab,
    Map<String, Object?>? collected,
    bool running = true,
  }) async {
    final controller = NetworkInstanceController(
      id: 'n1',
      initialTab: initialTab,
      tab: tab,
      backend: FakeBackend(
        collected: () => running ? {'alpha': collected ?? _instance} : {},
      ),
    );
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      NetworkInstancePage(
        id: 'n1',
        initialTab: initialTab,
        tab: tab,
        controller: controller,
      ),
    );
    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('lists this device first, then the peers', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpInstance(tester);

    expect(find.text('me'), findsOneWidget);
    expect(find.text('peer-b'), findsOneWidget);
    expect(tester.getRect(find.text('me')).top, lessThan(tester.getRect(find.text('peer-b')).top));
    // One badge per protocol, and the identity and security tags.
    expect(find.text('TCP'), findsOneWidget);
    expect(find.text(strings.peerCredential), findsOneWidget);
    expect(find.text(strings.peerKeyVerified), findsOneWidget);
  });

  testWidgets('a network that is not running says so', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpInstance(tester, running: false);

    expect(find.text(strings.networkNotRunning), findsOneWidget);
  });

  testWidgets('a peer shows one chip per protocol, however many connections', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final payload =
        jsonDecode(jsonEncode(_instance)) as Map<String, Object?>;
    final pair =
        (payload['peer_route_pairs'] as List<Object?>).single
            as Map<String, Object?>;
    final peer = pair['peer'] as Map<String, Object?>;
    final connection =
        (peer['conns'] as List<Object?>).single as Map<String, Object?>;
    peer['conns'] = <Map<String, Object?>>[
      for (var index = 0; index < 3; index++)
        {...connection, 'tunnel': {'tunnel_type': 'tcp'}},
      {...connection, 'tunnel': {'tunnel_type': 'quic'}},
    ];
    await pumpInstance(tester, collected: payload);

    expect(find.text('TCP'), findsOneWidget);
    expect(find.text('QUIC'), findsOneWidget);

    final colors = Theme.of(tester.element(find.text('TCP'))).colorScheme;
    final chip = tester.widget<Badge>(
      find.ancestor(of: find.text('TCP'), matching: find.byType(Badge)),
    );
    expect(chip.backgroundColor, colors.secondaryContainer);
    expect(chip.textColor, colors.onSecondaryContainer);
  });

  testWidgets('a truncated hostname can be revealed, a short one cannot', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final longHost = 'host-${'x' * 80}';
    final myself = {
      ...(_instance['my_node_info']! as Map<String, Object?>),
      'hostname': longHost,
    };
    await pumpInstance(
      tester,
      collected: {..._instance, 'my_node_info': myself},
    );

    expect(find.byTooltip(longHost), findsOneWidget);
    expect(find.byTooltip('peer-b'), findsNothing);
  });

  testWidgets('a truncated summary can be revealed, a short one cannot', (
    tester,
  ) async {
    const long =
        '{"time":"2024-01-01T00:00:04Z","event":{"PeerConnAdded":{"peer_id":"7",'
        '"tunnel":{"remote_addr":{"url":"tcp://a-rather-long-hostname-for-'
        'wrapping.example.com:11010"},"tunnel_type":"tcp"}}}}';
    await tester.runAsync(seedNetworks);
    recordInstanceEvents('n1', [long, peer]);
    addTearDown(() => clearInstanceLogs('n1'));
    await pumpInstance(tester, initialTab: InstanceTab.logs);

    expect(
      find.byTooltip(formatLogSummary(LogEntry.parse(long), strings)),
      findsOneWidget,
    );
    expect(
      find.byTooltip(formatLogSummary(LogEntry.parse(peer), strings)),
      findsNothing,
    );
  });

  testWidgets('an instance without peers has its own empty state', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpInstance(tester, collected: const {'running': true});

    expect(find.text(strings.networkNoPeers), findsOneWidget);
  });

  testWidgets('a deleted network shows the not-found state', (tester) async {
    await tester.runAsync(seedNetworks);
    final controller = NetworkInstanceController(
      id: 'gone',
      backend: FakeBackend(),
    );
    addTearDown(controller.dispose);
    await pumpApp(tester, NetworkInstancePage(id: 'gone', controller: controller));

    expect(find.text(strings.networkMissing), findsWidgets);
    expect(find.text(strings.commonGoBack), findsOneWidget);
  });

  testWidgets('the requested tab opens with the localized summaries', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    recordInstanceEvents('n1', [version, peer, tun, listener]);
    addTearDown(() => clearInstanceLogs('n1'));
    await pumpInstance(tester, initialTab: InstanceTab.logs);

    expect(find.text(strings.logPeerAdded('2')), findsOneWidget);
    expect(find.text(strings.logTunDeviceError('none')), findsOneWidget);
    expect(find.text('me'), findsNothing);
  });

  testWidgets('the chips filter by category and wrap on a narrow screen', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    recordInstanceEvents('n1', [version, peer, tun, listener]);
    addTearDown(() => clearInstanceLogs('n1'));
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpInstance(tester, initialTab: InstanceTab.logs);

    expect(find.text('${strings.networkFilterAll} 4'), findsOneWidget);
    expect(find.text('${strings.networkFilterErrors} 2'), findsOneWidget);
    expect(find.text('${strings.networkPeers} 1'), findsOneWidget);
    // Wrapped onto more than one row.
    expect(
      tester.getRect(find.text('${strings.networkFilterAll} 4')).top,
      lessThan(tester.getRect(find.text('${strings.networkFilterConnections} 1')).top),
    );

    await tester.tap(find.text('${strings.networkFilterErrors} 2'));
    await tester.pumpAndSettle();

    expect(find.text(strings.logTunDeviceError('none')), findsOneWidget);
    expect(find.text(strings.logPeerAdded('2')), findsNothing);
  });

  testWidgets('an entry expands into its details', (tester) async {
    await tester.runAsync(seedNetworks);
    recordInstanceEvents('n1', [peer]);
    addTearDown(() => clearInstanceLogs('n1'));
    await pumpInstance(tester, initialTab: InstanceTab.logs);

    expect(find.byTooltip(strings.logCopyJson), findsNothing);
    final chip = find.widgetWithText(
      FilterChip,
      '${strings.networkFilterAll} 1',
    );
    final chipBefore = tester.widget<FilterChip>(chip);

    await tester.tap(find.text(strings.logPeerAdded('2')));
    await tester.pumpAndSettle();

    expect(find.text('event'), findsOneWidget);
    // Opening one entry rebuilds the list, not the chips above it.
    expect(
      identical(tester.widget<FilterChip>(chip), chipBefore),
      isTrue,
      reason: 'expanding an entry rebuilt the filter chips',
    );
    expect(find.byTooltip(strings.logCopyJson), findsOneWidget);
    expect(find.text('PeerAdded'), findsOneWidget);
  });

  testWidgets('the route tab and the tab controller stay in sync both ways', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    recordInstanceEvents('n1', [peer]);
    addTearDown(() => clearInstanceLogs('n1'));
    final tab = signal(InstanceTab.logs);
    addTearDown(tab.dispose);
    await pumpInstance(tester, tab: tab);

    expect(find.text(strings.logPeerAdded('2')), findsOneWidget);

    await tester.tap(find.text(strings.networkPeers));
    await tester.pumpAndSettle();
    expect(tab.value, InstanceTab.peers);
    expect(find.text(strings.logPeerAdded('2')), findsNothing);

    tab.value = InstanceTab.logs;
    await tester.pumpAndSettle();
    expect(find.text(strings.logPeerAdded('2')), findsOneWidget);
  });

  testWidgets('the not-found Go Back button opens the networks list', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final controller = NetworkInstanceController(
      id: 'gone',
      backend: FakeBackend(),
    );
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: '/instance',
      routes: [
        GoRoute(
          path: '/instance',
          builder: (context, state) =>
              NetworkInstancePage(id: 'gone', controller: controller),
        ),
        GoRoute(
          path: '/networks',
          builder: (context, state) =>
              const Scaffold(body: Text('networks list')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.commonGoBack));
    await tester.pumpAndSettle();

    expect(find.text('networks list'), findsOneWidget);
  });

  testWidgets('a route tab signal drives the page it builds', (tester) async {
    await tester.runAsync(seedNetworks);
    final tab = signal(InstanceTab.logs);
    addTearDown(tab.dispose);

    // This page builds its own controller, which talks to the app's real
    // backend: pump bounded frames instead of waiting for it.
    await pumpApp(tester, NetworkInstancePage(id: 'n1', tab: tab), settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(strings.networkNoEvents), findsOneWidget);

    await tester.tap(find.text(strings.networkPeers));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tab.value, InstanceTab.peers);
  });

  testWidgets('shows the collected instance details', (tester) async {
    await tester.runAsync(seedNetworks);
    final collected = await tester.runAsync(() async {
      final raw = await File(
        'test/fixtures/collected_instance.json',
      ).readAsString();
      return jsonDecode(raw) as Map<String, Object?>;
    });
    await pumpInstance(tester, collected: collected);

    // This device first, then the peer, with their connection badges.
    expect(find.text('host-b'), findsOneWidget);
    expect(find.text('host-a'), findsOneWidget);
    expect(find.text(strings.peerLocal), findsOneWidget);
    expect(find.text('P2P'), findsOneWidget);

    // Both virtual addresses, and the peer's latency in milliseconds.
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(find.text('10.144.0.1'), findsOneWidget);
    expect(find.text('0 ms'), findsOneWidget);

    final heights = [
      for (var index = 0; index < 2; index++)
        tester.getSize(find.byType(PeerCard).at(index)).height,
    ];
    expect(heights.first, heights.last);
    expect(heights.first, greaterThan(0));
  });

  testWidgets('the identity tags explain themselves on tap', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpInstance(
      tester,
      collected: {
        ..._instance,
        'peer_route_pairs': [
          {
            'route': {
              'peer_id': 2,
              'hostname': 'peer-b',
              'next_hop_peer_id': 3,
              'stun_info': {'udp_nat_type': 'PortRestricted'},
            },
            'peer': {
              'conns': [
                {
                  'peer_identity_type': 'SharedNode',
                  'secure_auth_level': 'NetworkSecretConfirmed',
                  'tunnel': {'tunnel_type': 'tcp'},
                  'stats': {'latency_us': '5000'},
                },
              ],
            },
          },
        ],
      },
    );

    expect(find.byTooltip(strings.peerSharedNodeDescription), findsOneWidget);
    expect(
      find.byTooltip(strings.peerSecretVerifiedDescription),
      findsOneWidget,
    );
    // Tapping the tag explains it, rather than only wiring a Tooltip up.
    expect(find.text(strings.peerSecretVerifiedDescription), findsNothing);

    await tester.tap(find.text(strings.peerSecretVerified));
    await tester.pumpAndSettle();

    expect(find.text(strings.peerSecretVerifiedDescription), findsOneWidget);
  });

  testWidgets('a new entry arrives at the top, and back-to-top returns there', (
    tester,
  ) async {
    // One summary is long enough to wrap, so the tiles differ in height.
    const long =
        '{"time":"2024-01-01T00:00:04Z","event":{"PeerConnAdded":{"peer_id":"7",'
        '"tunnel":{"remote_addr":{"url":"tcp://a-rather-long-hostname-for-wrapping'
        '.example.com:11010"},"tunnel_type":"tcp"}}}}';
    await tester.runAsync(seedNetworks);
    final versions = List.generate(30, (i) => version);
    // Newest first: the peer joins after the thirty connections.
    recordInstanceEvents('n1', [peer, long, ...versions]);
    addTearDown(() => clearInstanceLogs('n1'));
    await pumpInstance(tester, initialTab: InstanceTab.logs);

    final connection = strings.logConnectionError('none', 'none', 'none');
    expect(
      tester.getRect(find.text(strings.logPeerAdded('2'))).top,
      lessThan(tester.getRect(find.text(connection).first).top),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final viewed = find.text(connection).first;
    final before = tester.getRect(viewed);

    recordInstanceEvents('n1', [
      '{"time":"2024-01-01T00:00:09Z","event":{"PeerAdded":"9"}}',
      peer,
      long,
      ...versions,
    ]);
    await tester.pumpAndSettle();

    // Newer entries are laid out above the viewed one, so it does not move.
    expect(tester.getRect(viewed), before);
    expect(find.text(strings.logPeerAdded('9')), findsNothing);

    await tester.tap(find.byTooltip(strings.logBackToTop));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text(strings.logPeerAdded('9'))).top,
      lessThan(tester.getRect(find.text(connection).first).top),
    );

    // The very top, with entries of different heights.
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, position.minScrollExtent);
  });
}

/// The EasyTier information of one running instance with one peer.
final Map<String, Object?> _instance = {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': 'me',
    'version': '2.7.0',
    'stun_info': {'udp_nat_type': 'FullCone'},
    'virtual_ipv4': {
      'address': {'addr': (10 << 24) | (144 << 16) | 1},
    },
  },
  'peer_route_pairs': [
    {
      'route': {
        'peer_id': 2,
        'hostname': 'peer-b',
        'next_hop_peer_id': 2,
        'ipv4_addr': {
          'address': {'addr': (10 << 24) | (144 << 16) | 2},
        },
        'stun_info': {'udp_nat_type': 'PortRestricted'},
      },
      'peer': {
        'conns': [
          {
            'peer_identity_type': 'Credential',
            'secure_auth_level': 'PeerVerified',
            'tunnel': {'tunnel_type': 'tcp'},
            'stats': {'latency_us': '5000'},
          },
        ],
      },
    },
  ],
};

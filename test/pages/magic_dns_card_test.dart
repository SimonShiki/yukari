import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/backend/privilege.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/controllers/network_editor_magic_dns.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/widgets/instance_tabs.dart';
import 'package:yukari/pages/networks/widgets/magic_dns_card.dart';
import 'package:yukari/signals/instances.dart' as instances;
import 'package:yukari/signals/magic_dns.dart';
import 'package:yukari/system/magic_dns.dart';
import 'package:yukari/widgets/peer_card/peer_card.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';
import '../fake_system_command.dart';
import 'network_test_support.dart';

/// The running EasyTier information of the network `alpha`.
const _instance = <String, Object?>{
  'running': true,
  'my_node_info': <String, Object?>{
    'peer_id': 1,
    'hostname': 'laptop',
    'virtual_ipv4': '10.144.0.2/24',
  },
  'peer_route_pairs': <Object?>[],
  'events': <Object?>[],
};

Network _network({
  bool acceptDns = true,
  String? hostname = 'laptop',
  String zone = 'et.net.',
  String deviceName = '',
}) => Network()
  ..networkName = 'alpha'
  ..hostname = hostname
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..dnsZone = zone
    ..deviceName = deviceName);

/// Seeds the saved network and, when asked, one running instance of it.
Future<void> _seed(
  WidgetTester tester, {
  required Network network,
  bool running = false,
}) => tester.runAsync(() async {
  await seedWith({'n1': network});
  if (running) {
    await instances.refreshInstances(
      FakeBackend(collected: () => {'alpha': _instance}),
    );
  }
});

/// Whether a selectable value on screen contains [part].
bool _shows(WidgetTester tester, String part) => tester
    .widgetList<SelectableText>(find.byType(SelectableText))
    .any((text) => (text.data ?? '').contains(part));

Future<MagicDnsController> _pumpCard(
  WidgetTester tester,
  MagicDnsSystem system,
) async {
  final controller = MagicDnsController(networkId: 'n1', system: system);
  addTearDown(controller.dispose);
  await pumpApp(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: MagicDnsCard(networkId: 'n1', controller: controller),
      ),
    ),
  );
  // A problem state waits for the automatic setup's moment before showing.
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  useDeterministicCursor();
  setUp(resetMagicDnsDismissedCards);

  testWidgets('a stopped network explains the setup and probes nothing', (
    tester,
  ) async {
    final command = FakeSystemCommand(
      runHandler: (_, _) => throw StateError('nothing may run'),
    );
    await _seed(tester, network: _network());

    await _pumpCard(tester, linuxSystem(command));

    expect(find.text(strings.magicDnsTitle), findsOneWidget);
    expect(_shows(tester, '100.100.100.101'), isTrue);
    expect(_shows(tester, 'laptop.et.net'), isTrue);
    expect(find.text(strings.magicDnsStartManual), findsOneWidget);
    expect(find.text(strings.magicDnsApply), findsNothing);
    expect(command.runs, isEmpty);
  });

  testWidgets('a problem state waits for the automatic setup before showing', (
    tester,
  ) async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    await _seed(tester, network: _network(), running: true);
    final controller = MagicDnsController(
      networkId: 'n1',
      system: linuxSystem(command),
    );
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MagicDnsCard(networkId: 'n1', controller: controller),
        ),
      ),
    );
    expect(
      find.text(strings.magicDnsTitle),
      findsNothing,
      reason: 'the automatic setup may still be finishing',
    );

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text(strings.magicDnsTitle), findsOneWidget);
  });

  testWidgets('a running network without system DNS offers the action', (
    tester,
  ) async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    await _seed(tester, network: _network(), running: true);

    await _pumpCard(tester, linuxSystem(command));

    expect(find.text(strings.magicDnsMissing('et.net')), findsOneWidget);
    expect(find.text(strings.magicDnsApply), findsOneWidget);
    expect(
      _shows(tester, 'sudo resolvectl dns et_12_xoih 100.100.100.101'),
      isTrue,
      reason: 'the manual fallback is copyable',
    );
  });

  testWidgets('applying configures the link and hides the card', (
    tester,
  ) async {
    var configured = false;
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => configured),
      elevateHandler: (executable, _) async {
        if (executable == 'sh') configured = true;
      },
    );
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, linuxSystem(command));

    await tester.tap(find.text(strings.magicDnsApply));
    await tester.pumpAndSettle();

    expect(configured, isTrue);
    expect(
      command.elevated.single.$1,
      'sh',
      reason: 'both steps share one elevation prompt',
    );
    expect(
      find.text(strings.magicDnsTitle),
      findsNothing,
      reason: 'a configured system DNS needs no card',
    );
  });

  testWidgets('a network that starts configured shows no card', (tester) async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => true),
    );
    await _seed(tester, network: _network(), running: true);

    await _pumpCard(tester, linuxSystem(command));

    expect(find.text(strings.magicDnsTitle), findsNothing);
    expect(command.elevated, isEmpty);
  });

  testWidgets('a failed apply can be cleaned up with reset', (tester) async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(),
      elevateHandler: (executable, _) async {
        if (executable == 'sh') {
          throw const ElevationException('Authorization was dismissed');
        }
      },
    );
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, linuxSystem(command));

    await tester.tap(find.text(strings.magicDnsApply));
    await tester.pumpAndSettle();
    expect(
      find.text(strings.magicDnsFailed('Authorization was dismissed')),
      findsOneWidget,
    );

    await tester.tap(find.text(strings.magicDnsReset));
    await tester.pumpAndSettle();

    expect(command.elevated.last.$1, 'resolvectl');
    expect(command.elevated.last.$2, ['revert', 'et_12_xoih']);
    expect(find.text(strings.magicDnsMissing('et.net')), findsOneWidget);
  });

  testWidgets('a late automatic setup hides the shown card', (tester) async {
    var configured = false;
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => configured),
    );
    await _seed(tester, network: _network(), running: true);
    final controller = MagicDnsController(
      networkId: 'n1',
      system: linuxSystem(command),
    );
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MagicDnsCard(networkId: 'n1', controller: controller),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text(strings.magicDnsTitle), findsOneWidget);

    // The automatic setup finishes after the card appeared: the next instance
    // collection re-probes and hides it.
    configured = true;
    await instances.refreshInstances(
      FakeBackend(collected: () => {'alpha': _instance}),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.magicDnsTitle), findsNothing);
  });

  testWidgets('closing the card hides it until the network stops', (
    tester,
  ) async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, linuxSystem(command));
    expect(find.text(strings.magicDnsTitle), findsOneWidget);

    await tester.tap(find.byTooltip(strings.magicDnsDismiss));
    await tester.pumpAndSettle();

    expect(find.text(strings.magicDnsTitle), findsNothing);
    expect(magicDnsDismissedCards.value, contains('n1'));

    // The next start shows the card again.
    instances.initInstances();
    await tester.pumpAndSettle();
    expect(find.text(strings.magicDnsTitle), findsOneWidget);
  });

  testWidgets('a dismissed elevation says why and keeps the action', (
    tester,
  ) async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(),
      elevateHandler: (_, _) async =>
          throw const ElevationException('Authorization was dismissed'),
    );
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, linuxSystem(command));

    await tester.tap(find.text(strings.magicDnsApply));
    await tester.pumpAndSettle();

    expect(
      find.text(strings.magicDnsFailed('Authorization was dismissed')),
      findsOneWidget,
    );
    expect(find.text(strings.magicDnsApply), findsOneWidget);

    // A later collection must not replace the failure (and its reset action)
    // with the missing state a quiet probe would find.
    await instances.refreshInstances(
      FakeBackend(collected: () => {'alpha': _instance}),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(strings.magicDnsFailed('Authorization was dismissed')),
      findsOneWidget,
    );
    expect(find.text(strings.magicDnsReset), findsOneWidget);
  });

  testWidgets('a host without resolved shows the resolv.conf fallback', (
    tester,
  ) async {
    final command = FakeSystemCommand(
      runHandler: (executable, _) => executable == 'ip'
          ? ok('100.100.100.101 dev et_12_xoih src 10.126.126.2 uid 1000')
          : null,
    );
    await _seed(tester, network: _network(), running: true);

    await _pumpCard(tester, linuxSystem(command));

    expect(find.text(strings.magicDnsNoResolved), findsOneWidget);
    expect(_shows(tester, 'nameserver 100.100.100.101'), isTrue);
    expect(_shows(tester, 'search et.net'), isTrue);
    expect(find.text(strings.magicDnsApply), findsNothing);
  });

  testWidgets('an interface that is not there can be checked again', (
    tester,
  ) async {
    var found = false;
    final command = FakeSystemCommand(
      runHandler: (executable, arguments) => executable == 'ip'
          ? ok(
              found
                  ? '100.100.100.101 dev et_12_xoih src 10.126.126.2 uid 1000'
                  : '',
            )
          : linuxHost()(executable, arguments),
    );
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, linuxSystem(command));

    expect(find.text(strings.magicDnsNoInterface), findsOneWidget);

    found = true;
    await tester.tap(find.text(strings.settingsCheckAgain));
    await tester.pumpAndSettle();

    expect(find.text(strings.magicDnsMissing('et.net')), findsOneWidget);
  });

  testWidgets('Windows with its automatic DNS shows no card', (tester) async {
    final command = FakeSystemCommand(
      runHandler: (_, _) => ok(
        'Ethernet adapter EasyTier:\n'
        '   DNS Servers . . . . . . . . . . . : 100.100.100.101\n',
      ),
    );
    await _seed(tester, network: _network(), running: true);

    await _pumpCard(tester, windowsSystem(command));

    expect(find.text(strings.magicDnsTitle), findsNothing);
    expect(command.elevated, isEmpty);
  });

  testWidgets('Windows without its DNS explains the conflict', (tester) async {
    final command = FakeSystemCommand(
      runHandler: (_, _) => ok('DNS Servers . . . : 8.8.8.8'),
    );
    await _seed(tester, network: _network(), running: true);

    await _pumpCard(tester, windowsSystem(command));

    expect(find.text(strings.magicDnsWindowsMissing), findsOneWidget);
    expect(find.text(strings.magicDnsConflictNote('et.net')), findsOneWidget);
    expect(find.text(strings.magicDnsWindowsTest), findsOneWidget);
    expect(
      _shows(tester, 'nslookup laptop.et.net 100.100.100.101'),
      isTrue,
      reason: 'the direct query bypasses the system resolver',
    );
    expect(command.elevated, isEmpty);
  });

  testWidgets('Windows checking again follows the reported DNS', (
    tester,
  ) async {
    var configured = false;
    final command = FakeSystemCommand(
      runHandler: (_, _) => ok(
        configured
            ? 'DNS Servers . . . . . . . . . . . : 100.100.100.101'
            : 'DNS Servers . . . . . . . . . . . : 8.8.8.8',
      ),
    );
    await _seed(tester, network: _network(), running: true);
    await _pumpCard(tester, windowsSystem(command));
    expect(find.text(strings.magicDnsWindowsMissing), findsOneWidget);

    configured = true;
    await tester.tap(find.text(strings.settingsCheckAgain));
    await tester.pumpAndSettle();

    expect(
      find.text(strings.magicDnsTitle),
      findsNothing,
      reason: 'a configured DNS hides the card',
    );
  });

  testWidgets('an unsupported platform shows no helper at all', (tester) async {
    final command = FakeSystemCommand();
    await _seed(tester, network: _network());

    await _pumpCard(
      tester,
      MagicDnsSystem(platform: MagicDnsPlatform.other, command: command),
    );

    expect(find.text(strings.magicDnsTitle), findsNothing);
  });

  testWidgets('the editor shows the helper while Magic DNS is on', (
    tester,
  ) async {
    await tester.runAsync(() => seedWith({'n1': _network(acceptDns: false)}));
    final controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);
    await pumpApp(tester, NetworkEditorPage(id: 'n1', controller: controller));

    await switchTab(tester, strings.networkAdvanced);
    expect(find.text(strings.magicDnsTitle), findsNothing);

    await tapSaving(tester, find.text(strings.advancedMagicDns));

    expect(find.text(strings.magicDnsTitle), findsOneWidget);
    expect(_shows(tester, '100.100.100.101'), isTrue);
  });

  testWidgets('a running network shows the helper above its peers', (
    tester,
  ) async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _seed(tester, network: _network(), running: true);
    final controller = NetworkInstanceController(
      id: 'n1',
      backend: FakeBackend(collected: () => {'alpha': _instance}),
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.refresh);

    await pumpApp(
      tester,
      Scaffold(
        body: InstancePeersTab(
          controller: controller,
          magicDnsSystem: linuxSystem(command),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    final card = find.byType(MagicDnsCard);
    expect(card, findsOneWidget);
    expect(
      find.ancestor(of: card, matching: find.byType(SliverToBoxAdapter)),
      findsOneWidget,
      reason: 'the card is a scrolling sliver, not a fixed header',
    );
    expect(command.runs, isNotEmpty, reason: 'the injected system was used');
    expect(
      tester.getSize(find.byType(PeerCard).first).width,
      lessThanOrEqualTo(840),
      reason: 'peers keep the helper card\'s width cap on wide windows',
    );
  });
}

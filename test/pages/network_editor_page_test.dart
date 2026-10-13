import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/networks/editor_exit_guard.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/widgets/form_segments.dart';
import 'package:yukari/signals/networks.dart';
import 'package:yukari/utils/validator.dart';

import '../networks_fixture.dart';

void main() {
  setUp(seedNetworks);

  Future<void> pumpEditor(WidgetTester tester, [String id = 'n1']) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: NetworkEditorPage(id: id)));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  // The save queue outlives each test's fake-async zone, so trigger saves
  // from the real zone and give them a turn of the real event loop.
  Future<void> act(WidgetTester tester, void Function() action) async {
    await tester.runAsync(() async {
      action();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.showKeyboard(field(label));
    await act(tester, () => tester.testTextInput.enterText(text));
  }

  Future<void> toggle(WidgetTester tester, String title) {
    final tile = tester.widget<SwitchSegment>(
      find.widgetWithText(SwitchSegment, title),
    );
    return act(tester, () => tile.onChanged(!tile.value));
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the saved configuration', (tester) async {
    await pumpEditor(tester);
    expect(find.text('Edit alpha'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('unknown network shows not found', (tester) async {
    await pumpEditor(tester, 'missing');
    expect(find.text('Network not found'), findsOneWidget);
  });

  testWidgets('valid name is saved immediately and retitles the page', (
    tester,
  ) async {
    await pumpEditor(tester);
    await type(tester, 'Network Name', 'gamma');

    expect(networks.value['n1']!.networkName, 'gamma');
    expect((await persisted('n1')).networkName, 'gamma');
    expect(find.text('Edit gamma'), findsOneWidget);
  });

  testWidgets('duplicate or empty name is flagged and never saved', (
    tester,
  ) async {
    await pumpEditor(tester);

    await type(tester, 'Network Name', 'beta');
    expect(find.text('Network name already exists'), findsOneWidget);

    await type(tester, 'Network Name', '');
    expect(find.text('Network name cannot be empty'), findsOneWidget);

    expect(networks.value['n1']!.networkName, 'alpha');
    expect((await persisted('n1')).networkName, 'alpha');
  });

  testWidgets('DHCP switch saves immediately and unlocks IPv4', (tester) async {
    await pumpEditor(tester);
    TextField ipv4() => tester.widget<TextField>(
      find.descendant(
        of: field('IPv4 Address (CIDR)'),
        matching: find.byType(TextField),
      ),
    );
    expect(ipv4().enabled, isFalse);

    await toggle(tester, 'Enable DHCP');

    expect(networks.value['n1']!.dhcp, isFalse);
    expect(ipv4().enabled, isTrue);
  });

  testWidgets('invalid IPv4 is highlighted and rejected; fixing it saves', (
    tester,
  ) async {
    await pumpEditor(tester);
    await toggle(tester, 'Enable DHCP');

    await type(tester, 'IPv4 Address (CIDR)', '10.0.0.1');
    expect(
      find.text('Must be an IPv4 CIDR, e.g. 10.144.144.1/24'),
      findsOneWidget,
    );
    expect(networks.value['n1']!.ipv4, isNull);

    await type(tester, 'IPv4 Address (CIDR)', '10.0.0.1/24');
    expect(
      find.text('Must be an IPv4 CIDR, e.g. 10.144.144.1/24'),
      findsNothing,
    );
    expect(networks.value['n1']!.ipv4, '10.0.0.1/24');
  });

  testWidgets('out-of-range MTU is rejected', (tester) async {
    await pumpEditor(tester);
    await openAdvanced(tester);

    await type(tester, 'MTU', '100');
    expect(
      find.text('MTU must be a number between 576 and 65535'),
      findsOneWidget,
    );
    expect(networks.value['n1']!.flags.mtu, 1380);

    await type(tester, 'MTU', '1400');
    expect(networks.value['n1']!.flags.mtu, 1400);
  });

  testWidgets('invalid input and its error survive switching tabs', (
    tester,
  ) async {
    await pumpEditor(tester);
    await type(tester, 'Network Name', 'beta');

    await openAdvanced(tester);
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();

    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Network name already exists'), findsOneWidget);
  });

  testWidgets('invalid private key never enables secure mode', (tester) async {
    await pumpEditor(tester);
    await openAdvanced(tester);

    await type(tester, 'Node Private Key (Base64)', 'AAAA');
    expect(find.text('Must be a base64-encoded 32-byte key'), findsOneWidget);
    expect(networks.value['n1']!.secureMode, isNull);
  });

  testWidgets('subnet proxy lines are saved once valid', (tester) async {
    await pumpEditor(tester);
    await openAdvanced(tester);

    await type(tester, 'Subnet Proxy', '192.168.1.0/24->10.0.0.0/16');
    expect(find.textContaining('same prefix'), findsOneWidget);
    expect(networks.value['n1']!.proxyNetworks, isEmpty);

    await type(tester, 'Subnet Proxy', '192.168.1.0/24->10.1.1.0/24\n');
    final proxy = networks.value['n1']!.proxyNetworks.single;
    expect(proxy.cidr, '192.168.1.0/24');
    expect(proxy.mappedCidr, '10.1.1.0/24');
  });

  testWidgets('DNS suffix shows only with Magic DNS and keeps MTU input', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAdvanced(tester);
    expect(field('DNS Suffix'), findsNothing);

    await type(tester, 'MTU', '1');
    await toggle(tester, 'Magic DNS');
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);

    await type(tester, 'DNS Suffix', 'not a domain');
    expect(find.text('Must be a domain, e.g. et.net.'), findsOneWidget);
    await type(tester, 'DNS Suffix', 'home.lan.');
    expect(networks.value['n1']!.flags.dnsZone, 'home.lan.');

    await toggle(tester, 'Magic DNS');
    expect(field('DNS Suffix'), findsNothing);
  });

  testWidgets('uncommon sections start collapsed and expand on tap', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAdvanced(tester);
    expect(find.text('Lazy P2P'), findsNothing);

    await tester.tap(find.text('P2P & NAT Traversal'));
    await tester.pumpAndSettle();
    await toggle(tester, 'Lazy P2P');
    expect(networks.value['n1']!.flags.lazyP2p, isTrue);
  });

  testWidgets('enabling the VPN portal gives it a key and an address', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAdvanced(tester);
    await tester.tap(find.text('VPN Portal'));
    await tester.pumpAndSettle();

    await toggle(tester, 'Enable VPN Portal');
    final portal = networks.value['n1']!.vpnPortal!;
    expect(portal.enabled, isTrue);
    expect(portal.wireguardListen, '0.0.0.0:22022');
    expect(validatePrivateKey(portal.wireguardPrivateKey!), isNull);

    await toggle(tester, 'Enable VPN Portal');
    expect(networks.value['n1']!.vpnPortal!.enabled, isFalse);
    expect(
      networks.value['n1']!.vpnPortal!.wireguardPrivateKey,
      portal.wireguardPrivateKey,
    );
  });

  testWidgets('peer dialog highlights every invalid field', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Add Peer'));
    await tester.pumpAndSettle();

    await tester.enterText(field('URL'), 'example.com:11010');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Peer ID cannot be empty'), findsOneWidget);
    expect(
      find.text('Must be an address without port, query or fragment'),
      findsOneWidget,
    );
    expect(
      find.text('Port must be a number between 1 and 65535'),
      findsOneWidget,
    );
    expect(find.text('At least one protocol must be selected'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(networks.value['n1']!.nodes, isEmpty);
  });

  testWidgets('valid peer is added and saved', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Add Peer'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Peer ID'), 'relay');
    await tester.enterText(field('URL'), 'example.com');
    await tester.enterText(field('Port'), '11010');
    await tester.tap(find.text('TCP'));
    await tester.pump();
    await act(
      tester,
      () => tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed!(),
    );
    await tester.pumpAndSettle();

    final nodes = networks.value['n1']!.nodes;
    expect(nodes.single.id, 'relay');
    expect(
      nodes.single.endpoint(nodes.single.protocols.single).toString(),
      'tcp://example.com:11010',
    );
    expect(find.text('relay'), findsOneWidget);

    // Tapping the peer opens it for editing.
    await tester.tap(find.text('relay'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'relay'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await act(tester, () => tester.tap(find.byTooltip('Delete peer')));
    await tester.pumpAndSettle();
    expect(networks.value['n1']!.nodes, isEmpty);
    expect(find.text('No peers configured'), findsOneWidget);
  });

  group('leaving with invalid input', () {
    Future<void> pumpRoutedEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/edit/n1',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Text('Home'),
            routes: [
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) =>
                    NetworkEditorPage(id: state.pathParameters['id']!),
                onExit: (context, state) =>
                    confirmLeavingPage(context, state.pageKey),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    Future<void> goBack(WidgetTester tester) async {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('valid edits leave without asking', (tester) async {
      await pumpRoutedEditor(tester);
      await type(tester, 'Network Name', 'gamma');
      await goBack(tester);

      expect(find.text('Discard invalid changes?'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('asks before discarding, and can keep editing', (tester) async {
      await pumpRoutedEditor(tester);
      await type(tester, 'Network Name', 'beta');

      await goBack(tester);
      expect(find.text('Discard invalid changes?'), findsOneWidget);
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit alpha'), findsOneWidget);
      expect(find.text('Network name already exists'), findsOneWidget);

      await goBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(networks.value['n1']!.networkName, 'alpha');
    });

    testWidgets('also asks for invalid input on the other tab', (tester) async {
      await pumpRoutedEditor(tester);
      await openAdvanced(tester);
      await type(tester, 'MTU', '1');
      await tester.tap(find.text('Basic'));
      await tester.pumpAndSettle();

      await goBack(tester);
      expect(find.text('Discard invalid changes?'), findsOneWidget);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/widgets/form_section/form_segments.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/networks/editor_exit_guard.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/widgets/advanced_flags_section.dart';
import 'package:yukari/pages/networks/widgets/advanced_security_section.dart';
import 'package:yukari/pages/networks/widgets/editor_fields.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';

import '../networks_fixture.dart';
import 'network_test_support.dart';

void main() {
  useDeterministicCursor();

  late NetworkEditorController controller;
  late BuildContext pageContext;

  Future<void> pumpEditor(WidgetTester tester, {String id = 'n1'}) async {
    controller = NetworkEditorController(id: id, showMessage: (_) {});
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          pageContext = context;
          return NetworkEditorPage(id: id, controller: controller);
        },
      ),
    );
  }

  /// The `enabled`/`obscureText` flag of the field labelled [label].
  bool? flagOf(
    WidgetTester tester,
    String label,
    bool? Function(TextField) read,
  ) => read(
    tester.widget<TextField>(
      find.descendant(of: field(label), matching: find.byType(TextField)),
    ),
  );

  /// The trailing switch of the row titled [title].
  Switch switchOf(WidgetTester tester, String title) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchSegment),
      ),
      matching: find.byType(Switch),
    ),
  );

  Future<void> savedTyping(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await saving(tester, () => tester.enterText(finder, text));
  }

  testWidgets('shows the saved configuration', (tester) async {
    await tester.runAsync(
      () => seedWith({
        'n1': seededNetwork(
          hostname: 'me',
          dhcp: false,
          ipv4: '10.144.0.2/24',
          nodes: [
            Node(
              id: 'peer-a',
              url: Uri.parse('relay.example.com'),
              port: 11010,
              protocols: const [NodeProtocol.tcp],
            ),
          ],
        ),
      }),
    );
    await pumpEditor(tester);

    expect(find.text('alpha'), findsWidgets);
    expect(find.text('me'), findsOneWidget);
    expect(find.text('peer-a'), findsOneWidget);
    expect(find.text('10.144.0.2/24'), findsOneWidget);
    expect(flagOf(tester, strings.networkIpv4, (f) => f.enabled), isTrue);
  });

  testWidgets('an unknown id shows the not-found state', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester, id: 'gone');

    expect(find.text(strings.networkMissing), findsWidgets);
    expect(find.text(strings.networkMissingDescription), findsOneWidget);
    expect(find.text(strings.commonGoBack), findsOneWidget);
  });

  testWidgets('renaming retitles the page', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await saving(
      tester,
      () => tester.enterText(field(strings.networkName), 'renamed'),
    );

    expect(controller.working.value!.networkName, 'renamed');
    expect(find.text(strings.networkEditNamed('renamed')), findsOneWidget);
    expect((await tester.runAsync(() => persisted('n1')))!.networkName, 'renamed');
  });

  testWidgets('an empty or duplicate name is rejected and never saved', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await tester.enterText(field(strings.networkName), '   ');
    await tester.pumpAndSettle();
    expect(find.text(strings.validationNetworkEmpty), findsOneWidget);
    expect(controller.working.value!.networkName, 'alpha');

    await tester.enterText(field(strings.networkName), 'beta');
    await tester.pumpAndSettle();
    expect(find.text(strings.validationNetworkExists), findsOneWidget);
    expect(controller.working.value!.networkName, 'alpha');
    expect(find.text(strings.networkEditNamed('alpha')), findsOneWidget);
  });

  testWidgets('the DHCP switch saves and unlocks the IPv4 field', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    expect(flagOf(tester, strings.networkIpv4, (f) => f.enabled), isFalse);

    await saving(tester, () => tester.tap(find.text(strings.networkDhcp)));

    expect(controller.working.value!.dhcp, isFalse);
    expect(flagOf(tester, strings.networkIpv4, (f) => f.enabled), isTrue);

    await saving(
      tester,
      () => tester.enterText(field(strings.networkIpv4), '10.144.0.2/24'),
    );
    expect(controller.working.value!.ipv4, '10.144.0.2/24');
  });

  testWidgets('an invalid IPv4 is rejected, and fixing it saves', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    // DHCP keeps the address field disabled until it is turned off.
    await saving(tester, () => tester.tap(find.text(strings.networkDhcp)));

    await tester.enterText(field(strings.networkIpv4), 'nope');
    await tester.pumpAndSettle();
    expect(find.text(strings.validationIpv4Cidr), findsOneWidget);
    expect(controller.working.value!.ipv4, isNull);

    await saving(
      tester,
      () => tester.enterText(field(strings.networkIpv4), '10.144.0.2/24'),
    );
    expect(find.text(strings.validationIpv4Cidr), findsNothing);
    expect(controller.working.value!.ipv4, '10.144.0.2/24');
  });

  testWidgets('invalid input and its error survive a tab switch', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await saving(tester, () => tester.tap(find.text(strings.networkDhcp)));

    await tester.enterText(field(strings.networkIpv4), 'nope');
    await tester.pumpAndSettle();
    expect(find.text(strings.validationIpv4Cidr), findsOneWidget);

    await switchTab(tester, strings.networkAdvanced);
    await switchTab(tester, strings.networkBasic);

    expect(find.text('nope'), findsOneWidget);
    expect(find.text(strings.validationIpv4Cidr), findsOneWidget);
  });

  testWidgets('an out-of-range MTU is rejected, and a valid one saves', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedNetworkFlags);
    final mtu = field(strings.advancedMtuHelper);


    await tester.enterText(mtu, '100');
    await tester.pumpAndSettle();
    expect(
      find.text(strings.validationRange('MTU', '576', '65535')),
      findsOneWidget,
    );
    expect(controller.working.value!.flags.mtu, 1380);

    await savedTyping(tester, mtu, '1500');
    expect(controller.working.value!.flags.mtu, 1500);
  });

  testWidgets('a switch row shows its icon and toggles from the row', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedNetworkFlags);

    final title = find.text(strings.advancedEnableEncryption);
    expect(title, findsOneWidget);
    final row = find.ancestor(of: title, matching: find.byType(SwitchSegment));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.enhanced_encryption_rounded),
      ),
      findsOneWidget,
      reason: 'the switch row has a leading icon',
    );

    final enabled = controller.working.value!.flags.enableEncryption;
    // The whole row is the tap target, not only the switch thumb.
    await tapSaving(tester, title);
    expect(controller.working.value!.flags.enableEncryption, isNot(enabled));
  });

  testWidgets('the DNS suffix appears only with Magic DNS, keeping the MTU', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    expect(find.text(strings.advancedDnsSuffix), findsNothing);

    await typeInto(tester, strings.advancedMtuHelper, '1400');
    expect(find.text(strings.advancedDnsSuffix), findsNothing);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(find.text(strings.advancedDnsSuffix), findsOneWidget);
    expect(controller.working.value!.flags.acceptDns, isTrue);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(find.text(strings.advancedDnsSuffix), findsNothing);
    expect(find.text('1400'), findsOneWidget);
  });

  testWidgets('Magic DNS blocks No-TUN until it is turned off', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(controller.working.value!.flags.acceptDns, isTrue);

    // The row says why it cannot move, and swallows the tap.
    expect(switchOf(tester, strings.advancedNoTun).onChanged, isNull);
    expect(find.text(strings.advancedMagicDnsNeedsTun), findsOneWidget);

    await tapSaving(tester, find.text(strings.advancedNoTun));
    expect(controller.working.value!.flags.noTun, isFalse);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(controller.working.value!.flags.acceptDns, isFalse);
    expect(switchOf(tester, strings.advancedNoTun).onChanged, isNotNull);
    expect(find.text(strings.advancedMagicDnsNeedsTun), findsNothing);
    expect(find.text(strings.advancedNoTunSubtitle), findsOneWidget);

    await tapSaving(tester, find.text(strings.advancedNoTun));
    expect(controller.working.value!.flags.noTun, isTrue);
  });

  testWidgets('No-TUN blocks Magic DNS until it is turned off', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);

    await tapSaving(tester, find.text(strings.advancedNoTun));
    expect(controller.working.value!.flags.noTun, isTrue);

    expect(switchOf(tester, strings.advancedMagicDns).onChanged, isNull);
    expect(find.text(strings.advancedMagicDnsNeedsTun), findsOneWidget);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(controller.working.value!.flags.acceptDns, isFalse);
    expect(find.text(strings.advancedDnsSuffix), findsNothing);

    await tapSaving(tester, find.text(strings.advancedNoTun));
    expect(controller.working.value!.flags.noTun, isFalse);
    expect(switchOf(tester, strings.advancedMagicDns).onChanged, isNotNull);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(controller.working.value!.flags.acceptDns, isTrue);
    expect(find.text(strings.advancedDnsSuffix), findsOneWidget);
  });

  testWidgets('a saved network with both on can still turn either one off', (
    tester,
  ) async {
    await tester.runAsync(
      () => seedWith({
        'n1': seededNetwork(
          flags: NetworkFlags()
            ..acceptDns = true
            ..noTun = true,
        ),
      }),
    );
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);

    // Neither row is dead, so either side can break the pair up.
    expect(switchOf(tester, strings.advancedMagicDns).onChanged, isNotNull);
    expect(switchOf(tester, strings.advancedNoTun).onChanged, isNotNull);

    await tapSaving(tester, find.text(strings.advancedMagicDns));
    expect(controller.working.value!.flags.acceptDns, isFalse);
    expect(controller.working.value!.flags.noTun, isTrue);

    await saving(tester, () async {
      controller.update((n) => n.flags.acceptDns = true);
    });
    expect(switchOf(tester, strings.advancedNoTun).onChanged, isNotNull);

    await tapSaving(tester, find.text(strings.advancedNoTun));
    expect(controller.working.value!.flags.noTun, isFalse);
    expect(controller.working.value!.flags.acceptDns, isTrue);
  });

  testWidgets('only the uncommon sections start collapsed', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    // Sections 1-5 are always open.
    expect(find.text(strings.advancedSocks5Proxy), findsOneWidget);
    expect(find.text(strings.advancedSubnetProxy), findsOneWidget);
    expect(find.text(strings.advancedMtuHelper), findsOneWidget);
    expect(find.text(strings.advancedSecureMode), findsOneWidget);

    // P2P & NAT Traversal is collapsed until its title is tapped.
    expect(find.text(strings.advancedDisableP2p), findsNothing);
    await expandSection(tester, strings.advancedP2p);
    expect(find.text(strings.advancedDisableP2p), findsOneWidget);
  });

  testWidgets('a change elsewhere rebuilds the flags and security sections not', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    controller = NetworkEditorController(id: 'n1', showMessage: (_) {});
    addTearDown(controller.dispose);
    // Alone, without a Form around them, so only their own subscriptions can
    // make them rebuild.
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AdvancedFlagsSection(controller: controller),
              AdvancedSecuritySection(controller: controller),
            ],
          ),
        ),
      ),
    );

    final mtu = find.ancestor(
      of: find.text(strings.advancedMtuHelper),
      matching: find.byType(EditorTextField),
    );
    final security = find.ancestor(
      of: find.text(strings.advancedSecureMode),
      matching: find.byType(SwitchSegment),
    );
    final mtuBefore = tester.widget<EditorTextField>(mtu);
    final securityBefore = tester.widget<SwitchSegment>(security);

    await tester.runAsync(() async {
      controller.update((n) => n.flags.disableP2p = true);
      await saved.settled();
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      identical(tester.widget<EditorTextField>(mtu), mtuBefore),
      isTrue,
      reason: 'the flags section rebuilt',
    );
    expect(
      identical(tester.widget<SwitchSegment>(security), securityBefore),
      isTrue,
      reason: 'the security section rebuilt',
    );
  });

  testWidgets('secure mode generates a key pair and can hide it again', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedSecurity);
    expect(find.text(strings.advancedPrivateKey), findsNothing);

    await tapSaving(tester, find.text(strings.advancedSecureMode));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(controller.working.value!.secureMode!.enabled, isTrue);
    expect(controller.working.value!.secureMode!.localPublicKey, isNotNull);
    expect(
      flagOf(tester, strings.advancedPrivateKey, (f) => f.obscureText),
      isTrue,
    );

    await tester.tap(find.byTooltip(strings.advancedShowPrivateKey));
    await tester.pumpAndSettle();

    expect(
      flagOf(tester, strings.advancedPrivateKey, (f) => f.obscureText),
      isFalse,
    );
  });

  testWidgets('an invalid private key never reaches the model', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedSecurity);
    await tapSaving(tester, find.text(strings.advancedSecureMode));
    final generated = controller.working.value!.secureMode!.localPrivateKey;

    await tester.enterText(field(strings.advancedPrivateKey), 'not-a-key');
    await tester.pumpAndSettle();

    expect(find.text(strings.validationPrivateKey), findsOneWidget);
    expect(controller.working.value!.secureMode!.localPrivateKey, generated);
  });

  testWidgets('subnet proxy lines are saved once valid', (tester) async {
    await tester.runAsync(
      () => seedWith({
        'n1': seededNetwork(
          proxyNetworks: [
            ProxyNetwork(cidr: '10.0.0.0/24', allow: const ['10.0.0.1']),
          ],
        ),
      }),
    );
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedRouting);
    expect(find.text('10.0.0.0/24'), findsOneWidget);

    await typeInto(
      tester,
      strings.advancedSubnetProxy,
      '10.0.0.0/24->10.1.0.0/24',
    );

    final proxy = controller.working.value!.proxyNetworks.single;
    expect(proxy.cidr, '10.0.0.0/24');
    expect(proxy.mappedCidr, '10.1.0.0/24');
    // The rewritten line keeps the allow list the CIDR already had.
    expect(proxy.allow, ['10.0.0.1']);
  });

  testWidgets('enabling the VPN portal generates a key and an address', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedVpnPortal);

    await tapSaving(tester, find.text(strings.advancedEnableVpnPortal));

    final portal = controller.working.value!.vpnPortal!;
    expect(portal.enabled, isTrue);
    expect(portal.wireguardPrivateKey, isNotNull);
    expect(find.text('0.0.0.0:22022'), findsWidgets);
  });

  testWidgets('the tuning rows pick algorithms from a menu', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);
    await expandSection(tester, strings.advancedTuning);

    // The closed rows show the chosen algorithm's name as trailing text.
    expect(find.text('AES-128-GCM'), findsOneWidget);
    expect(find.text(strings.advancedCompressionNone), findsOneWidget);

    await tapVisible(tester, find.text('AES-128-GCM'));
    final menu = find.byType(M3EMenuPanel);
    expect(menu, findsOneWidget);
    // Every algorithm is offered once and the current one is checkmarked.
    expect(
      find.descendant(of: menu, matching: find.text('ChaCha20-Poly1305')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );

    // Picking one saves it and closes the menu.
    await tapSaving(tester, find.text('ChaCha20-Poly1305'));
    // The tap ran in the real zone, so flush its microtasks before pumping.
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(
      controller.working.value!.flags.encryptionAlgorithm,
      EncryptionAlgorithm.chacha20,
    );
    expect(find.text('ChaCha20-Poly1305'), findsOneWidget);

    await tester.runAsync(() async {
      controller.update(
        (n) => n.flags.compressionAlgorithm = CompressionAlgorithm.zstd,
      );
      await saved.settled();
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Zstandard'), findsOneWidget);
    expect(find.text('ChaCha20-Poly1305'), findsOneWidget);
  });

  testWidgets('the SOCKS5 field hints at its shape', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);

    expect(find.text('socks5://host:port'), findsOneWidget);
  });

  testWidgets('a peer and a listener can be deleted', (tester) async {
    await tester.runAsync(
      () => seedWith({
        'n1': seededNetwork(
          nodes: [
            Node(
              id: 'peer-a',
              url: Uri.parse('relay.example.com'),
              port: 11010,
              protocols: const [NodeProtocol.tcp],
            ),
          ],
          listeners: [Uri.parse('tcp://0.0.0.0:11010')],
        ),
      }),
    );
    await pumpEditor(tester);

    await tapSaving(tester, find.byTooltip(strings.networkDeletePeer));
    expect(find.text('peer-a'), findsNothing);
    expect(controller.nodes.value, isEmpty);

    await switchTab(tester, strings.networkAdvanced);
    await tapSaving(tester, find.byTooltip(strings.networkDeleteListener));

    expect(find.text('tcp://0.0.0.0:11010'), findsNothing);
    expect(controller.listeners.value, isEmpty);
  });

  testWidgets('an untouched editor never asks on a tab switch', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    await switchTab(tester, strings.networkAdvanced);
    await switchTab(tester, strings.networkBasic);

    expect(find.text(strings.networkDiscardTitle), findsNothing);
    // Nothing was touched, so there is no invalid input to discard.
    expect(hasInvalidInput(editorGuardKey('n1')), isFalse);
  });

  testWidgets('peer rows show protocol chips, not endpoint URLs', (tester) async {
    await tester.runAsync(
      () => seedWith({
        'n1': seededNetwork(
          nodes: [
            Node(
              id: 'peer-a',
              url: Uri.parse('relay.example.com'),
              port: 11010,
              protocols: const [NodeProtocol.tcp],
            ),
          ],
        ),
      }),
    );
    await pumpEditor(tester);

    expect(find.text('peer-a'), findsOneWidget);
    expect(find.textContaining('relay.example.com'), findsNothing);
    expect(find.text('TCP'), findsOneWidget);

    final colors = Theme.of(tester.element(find.text('TCP'))).colorScheme;
    final chip = tester.widget<Badge>(
      find.ancestor(of: find.text('TCP'), matching: find.byType(Badge)),
    );
    expect(chip.backgroundColor, colors.secondaryContainer);
    expect(chip.textColor, colors.onSecondaryContainer);
    expect(chip.backgroundColor, isNot(colors.error));
  });

  testWidgets('the peer and listener footers are labeled, end aligned', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);

    expect(find.text(strings.networkAddPeer), findsOneWidget);
    expect(find.text(strings.bookmarksFromBookmarks), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(strings.networkAddPeer),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Align &&
              widget.alignment == AlignmentDirectional.centerEnd,
        ),
      ),
      findsWidgets,
    );

    await switchTab(tester, strings.networkAdvanced);

    expect(
      find.text(strings.networkAddListeners(strings.networkListeners)),
      findsOneWidget,
    );

    await expandSection(tester, strings.advancedMappedListeners);

    expect(
      find.text(
        strings.networkAddListeners(strings.advancedMappedListeners),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the public key is read-only and copyable', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);
    await tapSaving(tester, find.text(strings.advancedSecureMode));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final publicKey = controller.working.value!.secureMode!.localPublicKey!;
    expect(publicKey, isNotEmpty);

    final publicKeyField = tester.widget<TextField>(
      find.descendant(
        of: field(strings.advancedPublicKey),
        matching: find.byType(TextField),
      ),
    );
    expect(publicKeyField.readOnly, isTrue);
    expect(publicKeyField.enabled, isTrue);
    expect(publicKeyField.controller!.text, publicKey);
    expect(find.byTooltip(strings.advancedShowPublicKey), findsOneWidget);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.byTooltip(strings.advancedCopyPublicKey));
    await tester.pumpAndSettle();

    final copied = [
      for (final call in calls)
        if (call.method == 'Clipboard.setData')
          (call.arguments as Map<Object?, Object?>)['text'],
    ];
    expect(copied, contains(publicKey), reason: 'clipboard calls: $calls');
    expect(find.text(strings.advancedPublicKeyCopied), findsOneWidget);
  });

  testWidgets('valid edits leave silently', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await typeInto(tester, strings.networkName, 'renamed');

    final result = confirmLeavingPage(pageContext, editorGuardKey('n1'));
    await tester.pumpAndSettle();

    expect(find.text(strings.networkDiscardTitle), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('invalid input asks, and can keep editing', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await tester.enterText(field(strings.networkName), '');
    await tester.pumpAndSettle();

    final result = confirmLeavingPage(pageContext, editorGuardKey('n1'));
    await tester.pumpAndSettle();
    expect(find.text(strings.networkDiscardTitle), findsOneWidget);

    // Keeping the edits is the cancel action, and discarding is destructive.
    expect(
      find.widgetWithText(TextButton, strings.networkKeepEditing),
      findsOneWidget,
    );
    final confirm = find.widgetWithText(FilledButton, strings.networkDiscard);
    final button = tester.widget<FilledButton>(confirm);
    final scheme = Theme.of(tester.element(confirm)).colorScheme;
    expect(button.style?.backgroundColor?.resolve({}), scheme.error);
    expect(button.style?.foregroundColor?.resolve({}), scheme.onError);

    await tester.tap(find.text(strings.networkKeepEditing));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(find.text(strings.networkBasic), findsOneWidget);
  });

  testWidgets('invalid input on the other tab blocks too', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpEditor(tester);
    await switchTab(tester, strings.networkAdvanced);
    await tester.enterText(field(strings.advancedSocks5Proxy), 'nope');
    await tester.pumpAndSettle();
    expect(find.text(strings.validationSocks), findsOneWidget);
    await switchTab(tester, strings.networkBasic);
    expect(find.text(strings.validationSocks), findsNothing);

    final result = confirmLeavingPage(pageContext, editorGuardKey('n1'));
    await tester.pumpAndSettle();
    expect(find.text(strings.networkDiscardTitle), findsOneWidget);

    await tester.tap(find.text(strings.networkDiscard));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });
}

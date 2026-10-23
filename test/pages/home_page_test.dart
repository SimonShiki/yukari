import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';
import 'package:yukari/controllers/home_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/backend.dart';
import 'package:yukari_core/models/peer.dart';
import 'package:yukari/pages/home/home_page.dart';
import 'package:yukari/widgets/link_list/link_list.dart';
import 'package:yukari/pages/home/widgets/dashboard_card.dart';
import 'package:yukari/pages/home/widgets/dashboard_skeleton.dart';
import 'package:yukari/pages/home/widgets/dashboard_value.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/utils/stun_probe.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

/// A [FakeBackend] whose reported instances and answer timing tests control.
class _HomeBackend extends FakeBackend {
  _HomeBackend({this.infos = const {}, this.gate});

  Map<String, Object?> infos;

  /// While set, [collectInfos] waits for it, holding the pre-refresh state.
  Completer<void>? gate;

  @override
  Future<Map<String, String>> collectInfos() async {
    final pending = gate;
    if (pending != null) await pending.future;
    return {
      for (final entry in infos.entries) entry.key: jsonEncode(entry.value),
    };
  }
}

/// A backend that cannot take requests, as when the service is not running.
class _UnreachableBackend extends _HomeBackend {
  final Signal<BackendStatus> _status = signal(BackendStatus.unavailable);

  @override
  ReadonlySignal<BackendStatus> get status => _status;
}

void main() {
  HomeController controller({
    required FakeBackend backend,
    Future<NatProbe> Function()? probe,
  }) => HomeController(
    backend: backend,
    probe:
        probe ??
        () async => const NatProbe(
          publicAddress: '203.0.113.7',
          natType: NatType.portRestricted,
        ),
    probeServiceVersion: () async => null,
  );

  /// Pumps the page behind a router, as the app's shell routes it.
  Future<void> pumpHome(
    WidgetTester tester, {
    required HomeController controller,
    Size size = const Size(1000, 900),
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: const [AppLocalizations.delegate],
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) {
                final page = HomePage(controller: controller);
                if (!disableAnimations) return page;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: page,
                );
              },
            ),
            GoRoute(
              path: '/networks',
              builder: (context, state) => const _Route('networks route'),
            ),
            GoRoute(
              path: '/networks/create',
              builder: (context, state) => const _Route('create route'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const _Route('settings route'),
            ),
            GoRoute(
              path: '/about',
              builder: (context, state) => const _Route('about route'),
            ),
          ],
        ),
      ),
    );
  }

  /// The card at [index] in the stat grid.
  Finder cardAt(int index) => find.byType(DashboardCard).at(index);

  /// Where the card at [index] starts laying its content out.
  double contentLeft(WidgetTester tester, int index) =>
      tester.getRect(cardAt(index)).left + 16;

  /// The card's content width, inside its 16px padding.
  double contentWidth(WidgetTester tester, int index) =>
      tester.getSize(cardAt(index)).width - 32;

  /// The [text] inside the card at [index], which must start at its content
  /// edge rather than being centered by a shrink-wrapped parent.
  void expectContentLeft(WidgetTester tester, int index, String text) {
    final finder = find.descendant(
      of: cardAt(index),
      matching: find.text(text),
    );
    expect(finder, findsOneWidget);
    expect(
      tester.getTopLeft(finder).dx,
      contentLeft(tester, index),
      reason: '"$text" must start at the card content edge',
    );
  }

  /// Settles the first refresh and the cross-fade that replaces the skeleton.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<double> cardHeights(WidgetTester tester) => [
    for (var index = 0; index < 4; index++)
      tester.getSize(find.byType(DashboardCard).at(index)).height,
  ];

  testWidgets('shows the header and four skeletons until the first refresh', (
    tester,
  ) async {
    final gate = Completer<void>();
    final answer = Completer<NatProbe>();
    final backend = _HomeBackend(infos: {'alpha': _info()}, gate: gate);
    final home = controller(backend: backend, probe: () => answer.future);
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await tester.pump();

    final semantics = tester.ensureSemantics();
    expect(find.text('Running in app mode'), findsOneWidget);
    expect(find.text('IP address'), findsOneWidget);
    expect(find.byType(DashboardSkeleton), findsNWidgets(4));
    final labels = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(DashboardSkeleton),
            matching: find.byType(Semantics),
          ),
        )
        .map((skeleton) => skeleton.properties.label)
        .toList();
    expect(labels, everyElement('Loading'));
    expect(find.textContaining('of 2 running'), findsNothing);
    final skeletons = cardHeights(tester);
    expect(skeletons.toSet(), hasLength(1));
    semantics.dispose();

    gate.complete();
    answer.complete(
      const NatProbe(publicAddress: null, natType: NatType.unknown),
    );
    await settle(tester);

    expect(find.byType(DashboardSkeleton), findsNothing);
    expect(find.text('1 of 2 running'), findsOneWidget);
    expect(find.text('Virtual IP'), findsOneWidget);
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(cardHeights(tester), skeletons);
    home.dispose();
  });

  testWidgets('shows the dashboard in one column at 400px', (tester) async {
    final home = controller(
      backend: _HomeBackend(infos: {'alpha': _info(natType: 'Symmetric')}),
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home, size: const Size(400, 900));
    await settle(tester);

    expect(find.text('Running in app mode'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('EasyTier 2.7.0-1649ec00'), findsOneWidget);
    expect(find.text('1 of 2 running'), findsOneWidget);
    expect(find.text('Virtual IP'), findsOneWidget);
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(find.text('Symmetric'), findsOneWidget);
    expect(find.text('Hard P2P · often relayed'), findsOneWidget);
    expect(find.textContaining('/s'), findsOneWidget);
    expect(find.text('Networks'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.byTooltip('Detect again'), findsNothing);
    expect(cardHeights(tester).toSet(), hasLength(1));
    expect(tester.getTopLeft(find.byType(DashboardCard).at(0)).dx, 16);
    expect(tester.getSize(find.byType(DashboardCard).at(0)).width, 368);
    home.dispose();
  });

  testWidgets('every dashboard card draws the app card surface', (
    tester,
  ) async {
    final home = controller(backend: _HomeBackend(infos: {'alpha': _info()}));
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.byType(Card), findsNothing);
    final colors = Theme.of(tester.element(find.byType(DashboardCard).first))
        .colorScheme;
    for (var index = 0; index < 4; index++) {
      final material = tester.widget<Material>(
        find
            .descendant(of: cardAt(index), matching: find.byType(Material))
            .first,
      );
      expect(material.color, colors.surfaceContainer);
      expect(material.elevation, 0);
      expect(
        material.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        reason: 'a dashboard card takes its fill and corner from CardSurface',
      );
    }
    home.dispose();
  });

  testWidgets('lists every virtual address with a +N more suffix', (
    tester,
  ) async {
    final home = controller(
      backend: _HomeBackend(
        infos: {
          'alpha': _info(virtualIpv4: '10.144.0.2'),
          'beta': _info(hostname: 'beta', virtualIpv4: '10.144.0.3'),
        },
      ),
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home, size: const Size(400, 900));
    await settle(tester);

    expect(find.text('2 of 2 running'), findsOneWidget);
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(find.text('alpha · +1 more'), findsOneWidget);
    expect(find.byTooltip('alpha\nbeta'), findsOneWidget);
    expect(
      find.byTooltip('10.144.0.2  alpha\n10.144.0.3  beta'),
      findsOneWidget,
    );
    // The tooltip wrapper must not shrink the value slot either.
    expectContentLeft(tester, 1, '10.144.0.2');
    home.dispose();
  });

  for (final width in [400.0, 1000.0]) {
    testWidgets('left-aligns every card line at ${width}px', (tester) async {
      final home = controller(
        // A short address, so the value column has to stretch rather than
        // being clamped to the card width by a long line.
        backend: _HomeBackend(
          infos: {'alpha': _info(natType: 'Symmetric', virtualIpv4: '1.2.3.4')},
        ),
      );
      await tester.runAsync(seedNetworks);
      await pumpHome(tester, controller: home, size: Size(width, 900));
      await settle(tester);

      expectContentLeft(tester, 0, '1 of 2 running');
      expectContentLeft(tester, 0, 'alpha');
      expectContentLeft(tester, 1, '1.2.3.4');
      expectContentLeft(tester, 2, 'Symmetric');
      expectContentLeft(tester, 3, '0 B received · 0 B sent');

      // The icon-led P2P line starts at the content edge too.
      final p2p = find.descendant(
        of: cardAt(2),
        matching: find.byType(DashboardSupportingLine),
      );
      expect(p2p, findsOneWidget);
      expect(tester.getTopLeft(p2p).dx, contentLeft(tester, 2));
      home.dispose();
    });

    testWidgets('draws full-width skeleton bars at ${width}px', (tester) async {
      final gate = Completer<void>();
      final answer = Completer<NatProbe>();
      final backend = _HomeBackend(infos: {'alpha': _info()}, gate: gate);
      final home = controller(backend: backend, probe: () => answer.future);
      await tester.runAsync(seedNetworks);
      await pumpHome(tester, controller: home, size: Size(width, 900));
      await tester.pump();

      for (var index = 0; index < 4; index++) {
        final inner = contentWidth(tester, index);
        final skeleton = find.descendant(
          of: cardAt(index),
          matching: find.byType(DashboardSkeleton),
        );
        expect(skeleton, findsOneWidget);

        final bars = find.descendant(
          of: skeleton,
          matching: find.byType(FractionallySizedBox),
        );
        expect(bars, findsNWidgets(2), reason: 'one bar per line');
        final valueBar = tester.getSize(bars.first).width;
        final supportingBar = tester.getSize(bars.last).width;
        expect(
          valueBar,
          greaterThan(inner * 0.8),
          reason: 'the value bar spans the card, not a sliver',
        );
        expect(supportingBar, greaterThan(inner * 0.4));
        expect(supportingBar, lessThan(valueBar));
        expect(tester.getTopLeft(bars.first).dx, contentLeft(tester, index));

        final opacities = tester
            .widgetList<FadeTransition>(
              find.descendant(
                of: skeleton,
                matching: find.byType(FadeTransition),
              ),
            )
            .map((fade) => fade.opacity.value);
        expect(opacities, isNotEmpty);
        expect(opacities.every((opacity) => opacity > 0), isTrue);
      }
      home.dispose();
    });
  }

  testWidgets('keeps the skeleton fully visible without animations', (
    tester,
  ) async {
    final backend = _HomeBackend(
      infos: {'alpha': _info()},
      gate: Completer<void>(),
    );
    final home = controller(backend: backend);
    await tester.runAsync(seedNetworks);
    await pumpHome(
      tester,
      controller: home,
      size: const Size(400, 900),
      disableAnimations: true,
    );
    await tester.pump();

    final skeleton = find.descendant(
      of: cardAt(0),
      matching: find.byType(DashboardSkeleton),
    );
    final bar = find
        .descendant(of: skeleton, matching: find.byType(FractionallySizedBox))
        .first;
    expect(
      tester.getSize(bar).width,
      greaterThan(contentWidth(tester, 0) * 0.8),
    );
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(of: skeleton, matching: find.byType(FadeTransition))
          .first,
    );
    expect(fade.opacity.value, 1, reason: 'a static bar must be fully visible');
    home.dispose();
  });

  testWidgets('reveals a truncated card line in full', (tester) async {
    const name = 'a network name far longer than a phone card can show';
    final home = controller(
      backend: _HomeBackend(infos: {name: _info(natType: 'SymmetricEasyInc')}),
    );
    await tester.runAsync(() async {
      await seedNetworks();
      final network = saved.networks.value['n1']!;
      network.networkName = name;
      await saved.updateNetwork('n1', network);
    });
    await pumpHome(tester, controller: home, size: const Size(400, 900));
    await settle(tester);

    // The long name is ellipsized in both supporting lines it appears in.
    expect(find.byTooltip(name), findsNWidgets(2));
    // The long NAT label is ellipsized in the value line...
    expect(find.byTooltip('Predictable symmetric'), findsOneWidget);
    // ...as is the compact traffic value, wider than a 400px card.
    expect(find.byTooltip('↓ 0 B/s  ↑ 0 B/s'), findsOneWidget);
    // The selectable address keeps its own long press (copy), not a tooltip.
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byTooltip('10.144.0.2'), findsNothing);

    // Long-pressing the truncated supporting line shows the whole string.
    await tester.longPress(find.text(name).first);
    await tester.pumpAndSettle();
    expect(find.text(name), findsNWidgets(3));

    // And long-pressing a truncated value line does too.
    await tester.longPress(find.text('Predictable symmetric'));
    await tester.pumpAndSettle();
    expect(find.text('Predictable symmetric'), findsNWidgets(2));

    // Revealing text must not change the one-header-two-lines card height.
    expect(cardHeights(tester).toSet(), hasLength(1));
    home.dispose();
  });

  testWidgets('leaves a card line that fits plain, without a tooltip', (
    tester,
  ) async {
    final home = controller(
      backend: _HomeBackend(infos: {'alpha': _info(natType: 'Symmetric')}),
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home, size: const Size(400, 900));
    await settle(tester);

    expect(find.byTooltip('alpha'), findsNothing);
    expect(find.byTooltip('Symmetric'), findsNothing);
    expect(find.byTooltip('Hard P2P · often relayed'), findsNothing);
    expect(find.byTooltip('0 B received · 0 B sent'), findsNothing);
    home.dispose();
  });

  testWidgets('shows the dashboard in four columns at 1000px', (tester) async {
    final home = controller(
      backend: _HomeBackend(infos: {'alpha': _info(natType: 'Symmetric')}),
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.text('1 of 2 running'), findsOneWidget);
    expect(find.text('Virtual IP'), findsOneWidget);
    expect(find.text('10.144.0.2'), findsOneWidget);
    expect(find.text('Symmetric'), findsOneWidget);
    expect(find.text('Hard P2P · often relayed'), findsOneWidget);
    expect(find.textContaining('/s'), findsOneWidget);
    expect(find.text('Networks'), findsOneWidget);
    final cards = [
      for (var index = 0; index < 4; index++)
        tester.getRect(find.byType(DashboardCard).at(index)),
    ];
    expect(cards.first.left, 32);
    expect(cards.first.width, (1000 - 64 - 36) / 4);
    expect({for (final card in cards) card.top}, hasLength(1));
    expect(cardHeights(tester).toSet(), hasLength(1));
    home.dispose();
  });

  testWidgets('shows the public address when no network runs', (tester) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.text('0 of 2 running'), findsOneWidget);
    expect(find.text('Start one to connect.'), findsOneWidget);
    expect(find.text('Public IP'), findsOneWidget);
    expect(find.text('203.0.113.7'), findsOneWidget);
    expect(find.text('Seen by STUN servers'), findsOneWidget);
    expect(find.text('Port restricted cone'), findsOneWidget);
    expect(find.text('Fair P2P · usually direct'), findsOneWidget);
    expect(find.text('No traffic'), findsOneWidget);
    expect(find.text('No network is running.'), findsOneWidget);
    expect(find.byType(DashboardSkeleton), findsNothing);
    expect(find.byTooltip('Detect again'), findsOneWidget);
    expect(cardHeights(tester).toSet(), hasLength(1));
    home.dispose();
  });

  testWidgets('lays out two columns and 24px margins at 600px', (tester) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home, size: const Size(600, 900));
    await settle(tester);

    final cards = [
      for (var index = 0; index < 4; index++)
        tester.getRect(find.byType(DashboardCard).at(index)),
    ];
    expect(cards.first.left, 24);
    expect(cards.first.width, (600 - 48 - 12) / 2);
    expect(cards[1].top, cards[0].top);
    expect(cards[2].top, greaterThan(cards[0].top));
    expect(cards[2].left, cards[0].left);
    home.dispose();
  });

  testWidgets('the networks card opens the list', (tester) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    await tester.tap(find.text('Networks'));
    await settle(tester);

    expect(find.text('networks route'), findsOneWidget);
    home.dispose();
  });

  testWidgets('the networks card opens the creator when none is saved', (
    tester,
  ) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(() async => saved.init(temporaryStore()));
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.text('No networks'), findsOneWidget);
    expect(find.text('Tap to create one.'), findsOneWidget);
    await tester.tap(find.text('Networks'));
    await settle(tester);

    expect(find.text('create route'), findsOneWidget);
    home.dispose();
  });

  testWidgets('lists About below the dashboard cards', (tester) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    // The Logs entry is hidden until its backend feeding is implemented.
    expect(find.text('Logs'), findsNothing);
    expect(find.text('About'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsNothing);

    // The group sits below the last card, aligned with the cards' column.
    final links = find.byType(LinkList);
    expect(links, findsOneWidget);
    expect(
      tester.getTopLeft(links).dy,
      greaterThan(tester.getBottomLeft(cardAt(3)).dy),
    );
    expect(tester.getTopLeft(links).dx, tester.getTopLeft(cardAt(0)).dx);
    home.dispose();
  });

  testWidgets('the About row opens its page from the chevron too', (
    tester,
  ) async {
    final home = controller(backend: _HomeBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    // Tapping the trailing chevron, not the label, must still navigate.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await settle(tester);

    expect(find.text('about route'), findsOneWidget);
    home.dispose();
  });

  testWidgets('offers Settings only while the backend is unreachable', (
    tester,
  ) async {
    final home = controller(backend: _UnreachableBackend());
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.text('Unreachable'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await settle(tester);

    expect(find.text('settings route'), findsOneWidget);
    home.dispose();
  });

  testWidgets('hides re-detection while an EasyTier NAT type is shown', (
    tester,
  ) async {
    final home = controller(
      backend: _HomeBackend(infos: {'alpha': _info(natType: 'Symmetric')}),
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    expect(find.text('Symmetric'), findsOneWidget);
    expect(find.byTooltip('Detect again'), findsNothing);
    home.dispose();
  });

  testWidgets('disables re-detection while a probe is in flight', (
    tester,
  ) async {
    var gate = Completer<void>();
    final home = controller(
      backend: _HomeBackend(),
      probe: () async {
        await gate.future;
        return const NatProbe(publicAddress: null, natType: NatType.symmetric);
      },
    );
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    gate.complete();
    await settle(tester);

    final button = find.widgetWithIcon(IconButton, Icons.refresh_rounded);
    expect(find.text('Symmetric'), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);

    gate = Completer<void>();
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    gate.complete();
    await settle(tester);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    home.dispose();
  });

  testWidgets('changing a primitive rebuilds only the label that shows it', (
    tester,
  ) async {
    final home = controller(backend: _HomeBackend(infos: {'alpha': _info()}));
    await tester.runAsync(seedNetworks);
    await pumpHome(tester, controller: home);
    await settle(tester);

    final header = tester.widget<Text>(find.text('EasyTier 2.7.0-1649ec00'));
    final networks = tester.widget<Text>(find.text('1 of 2 running'));
    final traffic = tester.widget<Text>(find.textContaining('/s'));

    home.receiveRate.value = 1024;
    await tester.pump();

    expect(
      tester.widget<Text>(find.textContaining('/s')),
      isNot(same(traffic)),
    );
    expect(
      tester.widget<Text>(find.text('EasyTier 2.7.0-1649ec00')),
      same(header),
    );
    expect(tester.widget<Text>(find.text('1 of 2 running')), same(networks));
    home.dispose();
  });
}

/// A stand-in for the page another route shows.
class _Route extends StatelessWidget {
  const _Route(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(name));
}

/// EasyTier information for one running instance.
Map<String, Object?> _info({
  String hostname = 'alpha',
  String version = '2.7.0-1649ec00',
  String natType = 'Unknown',
  String virtualIpv4 = '10.144.0.2',
}) => {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': hostname,
    'version': version,
    'virtual_ipv4': {
      'address': {'addr': _ipv4(virtualIpv4)},
    },
    'stun_info': {'udp_nat_type': natType},
  },
  'peer_route_pairs': const [],
};

int _ipv4(String address) =>
    address.split('.').fold(0, (value, part) => (value << 8) | int.parse(part));

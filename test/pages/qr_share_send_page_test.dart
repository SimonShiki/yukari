import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart'
    show
        M3EButtonGroupType,
        M3EButtonSize,
        M3ESlider,
        M3EToggleButton,
        M3EToggleButtonGroup;
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/qr_share_send_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/share/qr_share_send_page.dart';
import 'package:yukari/pages/share/widgets/qr_matrix_view.dart';
import 'package:yukari/pages/share/widgets/qr_stream_settings.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

import '../networks_fixture.dart';
import '../share/share_fixture.dart';
import 'network_test_support.dart';

void main() {
  QrShareSendController controllerFor(ShareDocument document) {
    final controller = QrShareSendController(
      documents: [document],
      refreshRate: 60,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    QrShareSendPage page, {
    Size size = const Size(400, 800),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, page, settle: settle);
  }

  /// A saved network with one peer, so the page can resolve a share for it.
  Network networkWithPeer() => Network()
    ..networkName = 'alpha'
    ..networkSecret = 's3cret'
    ..nodes = [
      Node(
        id: 'relay.example.com:11010',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
    ];

  /// The semantic label the page gives the code.
  String? codeLabel(WidgetTester tester) => tester
      .widget<Semantics>(
        find
            .ancestor(
              of: find.byType(QrMatrixView),
              matching: find.byType(Semantics),
            )
            .first,
      )
      .properties
      .label;

  /// The live frame statistics line under the code.
  String frameStats(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .firstWhere((text) => RegExp(r'^Frame \d+ · ').hasMatch(text));

  /// The block-density group in the stream settings.
  M3EToggleButtonGroup densityGroup(WidgetTester tester) =>
      tester.widget<M3EToggleButtonGroup>(find.byType(M3EToggleButtonGroup));

  /// A share too big for one code, so the playback and tuning controls show.
  QrShareSendController streamingController() =>
      controllerFor(noiseNetworkShare(peers: 12));

  testWidgets('a network share shows what it carries and its code', (
    tester,
  ) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text(strings.shareKindNetwork), findsOneWidget);
    expect(
      find.text(
        '${strings.shareSendPeerCount(2)} · '
        '${strings.shareSendSecretIncluded}',
      ),
      findsOneWidget,
    );
    expect(find.text(strings.shareQrSecretWarning), findsOneWidget);
    expect(find.byType(QrMatrixView), findsOneWidget);
    expect(codeLabel(tester), strings.shareQrFrameSemanticLabel(1));
  });

  testWidgets('a share that fits one code is a still image, not a stream', (
    tester,
  ) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );

    expect(find.byTooltip(strings.shareQrPlay), findsNothing);
    expect(find.byTooltip(strings.shareQrPause), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    final stats = frameStats(tester);
    expect(stats, startsWith('Frame 1 · '));
    expect(stats, contains('1 block'));
    expect(
      find.text(strings.shareQrFps(controller.fps.value)),
      findsOneWidget,
      reason: 'the rate stays information even without a stream',
    );
    expect(codeLabel(tester), strings.shareQrFrameSemanticLabel(1));

    // No control can change a one-code share.
    expect(find.text(strings.shareQrFrameRate), findsNothing);
    expect(find.text(strings.shareQrDensity), findsNothing);
    expect(find.byType(M3ESlider), findsNothing);
    expect(find.byType(M3EToggleButtonGroup), findsNothing);
    // A one-code share tunes nothing, so the card holds the export alone.
    await tester.ensureVisible(find.text(strings.shareQrExportGif));
    await tester.pumpAndSettle();
    expect(
      [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(QrStreamSettings),
            matching: find.byType(Text),
          ),
        ))
          text.data,
      ],
      [strings.shareQrExportGif],
      reason: 'the card labels its one action and nothing else',
    );
  });

  testWidgets('a streaming share keeps its playback and tuning controls', (
    tester,
  ) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );

    expect(find.byTooltip(strings.shareQrPlay), findsOneWidget);
    expect(find.byType(M3ESlider), findsOneWidget);
    expect(find.byType(M3EToggleButtonGroup), findsOneWidget);
    expect(find.text(strings.shareQrFrameRate), findsOneWidget);
    expect(find.text(strings.shareQrDensity), findsOneWidget);
    expect(
      codeLabel(tester),
      strings.shareQrFrameSemanticLabel(controller.framesSent.value),
    );
  });

  testWidgets('play and pause drive the stream', (tester) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    expect(controller.playing.value, isFalse);

    await tester.tap(find.byTooltip(strings.shareQrPlay));
    await tester.pump();
    expect(controller.playing.value, isTrue);
    final first = controller.framesSent.value;

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.framesSent.value, greaterThan(first));
    expect(find.byTooltip(strings.shareQrPause), findsOneWidget);

    await tester.tap(find.byTooltip(strings.shareQrPause));
    await tester.pump();
    expect(controller.playing.value, isFalse);
    final paused = controller.framesSent.value;

    await tester.pump(const Duration(seconds: 1));
    expect(controller.framesSent.value, paused);
  });

  testWidgets('the frame rate slider writes the controller', (tester) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    expect(controller.fps.value, 15);
    final code = tester.widget<QrMatrixView>(find.byType(QrMatrixView));

    final slider = find.byType(M3ESlider);
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final track = tester.getRect(slider);
    await tester.tapAt(Offset(track.left + track.width * 0.8, track.center.dy));
    await tester.pumpAndSettle();

    expect(controller.fps.value, greaterThan(15));
    expect(controller.fps.value, lessThanOrEqualTo(maxShareFps));
    expect(find.text(strings.shareQrFps(controller.fps.value)), findsOneWidget);
    expect(
      identical(code, tester.widget<QrMatrixView>(find.byType(QrMatrixView))),
      isTrue,
      reason: 'a frame rate change does not rebuild the code',
    );
  });

  testWidgets('choosing Fast restarts the stream with one block', (
    tester,
  ) async {
    final controller = streamingController();
    expect(
      controller.blockCount.value,
      3,
      reason: 'the default Easy block size for this document',
    );
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    expect(densityGroup(tester).selectedIndex, 0);

    await tapVisible(tester, find.text(strings.shareQrDensityFast).first);

    expect(controller.density.value, QrShareDensity.fast);
    expect(controller.blockCount.value, 1);
    expect(controller.framesSent.value, 1);
    // The group follows the controller it reports to.
    expect(densityGroup(tester).selectedIndex, 2);
    final fast = tester.widget<M3EToggleButton>(
      find.byType(M3EToggleButton).at(2),
    );
    expect(fast.checked, isTrue);
  });

  testWidgets('the density is one connected group of the three choices', (
    tester,
  ) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );

    final group = densityGroup(tester);
    expect(group.type, M3EButtonGroupType.connected);
    expect(group.size, M3EButtonSize.sm);
    expect(group.selectedIndex, 0);
    expect(group.semanticLabel, strings.shareQrDensity);
    expect(
      [for (final action in group.actions) (action.label! as Text).data],
      [
        strings.shareQrDensityEasy,
        strings.shareQrDensityBalanced,
        strings.shareQrDensityFast,
      ],
    );
    // The group is the settings card's only density control.
    expect(find.byType(SegmentedButton<QrShareDensity>), findsNothing);
    // The settings card is the app's own surface.
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('the choices fill the card at a compact and a wide window', (
    tester,
  ) async {
    final controller = streamingController();
    Future<void> pumpAt(Size size) => pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
      size: size,
    );

    await pumpAt(const Size(400, 900));
    // The share column pads 16 a side, and so does the card.
    expect(
      tester.getSize(find.byType(M3EToggleButtonGroup)).width,
      closeTo(336, 0.5),
    );

    await pumpAt(const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(M3EToggleButtonGroup)).width,
      closeTo(536, 0.5),
    );
  });

  testWidgets('a missing network says so', (tester) async {
    await tester.runAsync(() => seedWith({}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['gone']),
    );

    expect(find.text(strings.shareSendNetworkMissing), findsOneWidget);
    expect(find.byType(QrMatrixView), findsNothing);
  });

  testWidgets('a network without peers asks for one first', (tester) async {
    await tester.runAsync(
      () => seedWith({'n1': Network()..networkName = 'alpha'}),
    );
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1']),
    );

    expect(find.text(strings.shareSendNoPeers), findsOneWidget);
  });

  testWidgets('lays out on a small phone screen', (tester) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
      size: const Size(360, 640),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(QrMatrixView), findsOneWidget);
  });

  testWidgets('the code stays black on white in a dark theme', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: QrShareSendPage(
          kind: ShareKind.network,
          ids: const ['n1'],
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrMatrixView), findsOneWidget);
    final surface = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(QrMatrixView),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((surface.decoration as BoxDecoration).color, Colors.white);
  });

  testWidgets('the code never grows past the scanner-friendly size', (
    tester,
  ) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
      size: const Size(1000, 900),
    );

    final code = tester.getSize(find.byType(QrMatrixView));
    expect(code.width, lessThanOrEqualTo(420));
    expect(code.height, code.width);
  });

  testWidgets('a new frame repaints the code, not the summary', (tester) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    final summary = tester.widget<Text>(find.text('alpha'));
    final before = tester
        .widget<QrMatrixView>(find.byType(QrMatrixView))
        .matrix;

    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    controller.pause();
    await tester.pump();

    final after = tester.widget<QrMatrixView>(find.byType(QrMatrixView));
    expect(identical(before, after.matrix), isFalse);
    expect(controller.framesSent.value, greaterThan(1));
    expect(
      codeLabel(tester),
      strings.shareQrFrameSemanticLabel(controller.framesSent.value),
    );
    expect(
      identical(summary, tester.widget<Text>(find.text('alpha'))),
      isTrue,
      reason: 'a frame change only rebuilds the code',
    );
  });

  testWidgets('a node share shows its address and protocols', (tester) async {
    final controller = controllerFor(sharedNodeDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.node,
        ids: const ['relay'],
        controller: controller,
      ),
    );

    expect(find.text('relay.example.com:11010'), findsOneWidget);
    expect(find.text(strings.shareKindNode), findsOneWidget);
    expect(find.text(strings.shareKindNetwork), findsNothing);
    expect(find.text(strings.shareQrSecretWarning), findsNothing);
    expect(find.text(strings.shareSendPeerCount(1)), findsNothing);
    expect(find.byType(QrMatrixView), findsOneWidget);
  });

  testWidgets('a bundle of ids shares every item with one code', (tester) async {
    await tester.runAsync(
      () => seedWith({
        'n1': networkWithPeer(),
        'n2': networkWithPeer()..networkName = 'beta',
      }),
    );
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1', 'n2']),
    );

    expect(find.text(strings.shareItems(2)), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text(strings.shareQrSecretWarning), findsOneWidget);
    expect(find.byType(QrMatrixView), findsOneWidget);
  });

  testWidgets('a bundle with one missing id shares nothing', (tester) async {
    await tester.runAsync(() => seedWith({'n1': networkWithPeer()}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1', 'gone']),
    );

    expect(find.text(strings.shareSendNetworkMissing), findsOneWidget);
    expect(find.byType(QrMatrixView), findsNothing);
  });

  testWidgets('a missing bookmark says so', (tester) async {
    await tester.runAsync(() => seedWith({}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.node, ids: ['gone']),
    );

    expect(find.text(strings.shareSendNodeMissing), findsOneWidget);
  });

  testWidgets('backgrounding the app pauses the stream', (tester) async {
    final controller = streamingController();
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    addTearDown(
      () => WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.playing.value, isTrue);

    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    expect(controller.playing.value, isFalse);
    final paused = controller.framesSent.value;

    await tester.pump(const Duration(seconds: 1));
    expect(controller.framesSent.value, paused);
  });

  testWidgets('the export progress replaces the export action', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        ids: const ['n1'],
        controller: controller,
      ),
    );
    await tester.ensureVisible(find.text(strings.shareQrExportGif));
    await tester.pumpAndSettle();

    controller.exporting.value = true;
    controller.exported.value = 2;
    await tester.pump();

    expect(
      find.text(strings.shareQrGifExporting(2, controller.gifFrameCount)),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(strings.shareQrExportGif), findsNothing);
    expect(
      find.widgetWithText(TextButton, strings.commonCancel),
      findsOneWidget,
    );

    controller.exporting.value = false;
    await tester.pump();
    expect(find.text(strings.shareQrExportGif), findsOneWidget);
  });

  testWidgets('a sender the page creates opens a fitting share still', (
    tester,
  ) async {
    await tester.runAsync(() => seedWith({'n1': networkWithPeer()}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1']),
    );

    expect(find.byTooltip(strings.shareQrPlay), findsNothing);
    final before = frameStats(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(frameStats(tester), before);
  });

  testWidgets('a sender the page creates streams a bigger share by itself', (
    tester,
  ) async {
    await tester.runAsync(() => seedWith({'n1': noiseNetwork(peers: 12)}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1']),
      settle: false,
    );

    expect(find.byTooltip(strings.shareQrPause), findsOneWidget);
    final before = frameStats(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(frameStats(tester), isNot(before));
  });

  testWidgets('a share the receiver would refuse says so', (tester) async {
    await tester.runAsync(
      () => seedWith({'n1': networkWithPeer()..networkName = 'a' * 200}),
    );
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, ids: ['n1']),
    );

    expect(find.text(strings.shareSendUnsupported), findsOneWidget);
    expect(find.byType(QrMatrixView), findsNothing);
  });
}

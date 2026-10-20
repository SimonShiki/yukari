import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart' show M3ESlider;
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/qr_share_send_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/share/qr_share_send_page.dart';
import 'package:yukari/pages/share/widgets/qr_matrix_view.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

import '../networks_fixture.dart';
import '../share/share_fixture.dart';
import 'network_test_support.dart';

void main() {
  QrShareSendController controllerFor(ShareDocument document) {
    final controller = QrShareSendController(
      document: document,
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

  testWidgets('a network share shows what it carries and its code', (
    tester,
  ) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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

  testWidgets('play and pause drive the stream', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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
    final controller = controllerFor(largeShareDocument());
    expect(
      controller.blockCount.value,
      3,
      reason: 'the default Easy block size for this document',
    );
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
        controller: controller,
      ),
    );

    await tapVisible(tester, find.text(strings.shareQrDensityFast));

    expect(controller.density.value, QrShareDensity.fast);
    expect(controller.blockCount.value, 1);
    expect(controller.framesSent.value, 1);
  });

  testWidgets('a missing network says so', (tester) async {
    await tester.runAsync(() => seedWith({}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, id: 'gone'),
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
      const QrShareSendPage(kind: ShareKind.network, id: 'n1'),
    );

    expect(find.text(strings.shareSendNoPeers), findsOneWidget);
  });

  testWidgets('lays out on a small phone screen', (tester) async {
    final controller = controllerFor(largeShareDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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
          id: 'n1',
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
        id: 'n1',
        controller: controller,
      ),
      size: const Size(1000, 900),
    );

    final code = tester.getSize(find.byType(QrMatrixView));
    expect(code.width, lessThanOrEqualTo(420));
    expect(code.height, code.width);
  });

  testWidgets('a new frame repaints the code, not the summary', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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
    expect(codeLabel(tester), strings.shareQrFrameSemanticLabel(2));
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
        id: 'relay',
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

  testWidgets('a missing bookmark says so', (tester) async {
    await tester.runAsync(() => seedWith({}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.node, id: 'gone'),
    );

    expect(find.text(strings.shareSendNodeMissing), findsOneWidget);
  });

  testWidgets('backgrounding the app pauses the stream', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    await pumpPage(
      tester,
      QrShareSendPage(
        kind: ShareKind.network,
        id: 'n1',
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
        id: 'n1',
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

  testWidgets('a sender the page creates starts streaming by itself', (
    tester,
  ) async {
    await tester.runAsync(() => seedWith({'n1': networkWithPeer()}));
    await pumpPage(
      tester,
      const QrShareSendPage(kind: ShareKind.network, id: 'n1'),
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
      const QrShareSendPage(kind: ShareKind.network, id: 'n1'),
    );

    expect(find.text(strings.shareSendUnsupported), findsOneWidget);
    expect(find.byType(QrMatrixView), findsNothing);
  });
}

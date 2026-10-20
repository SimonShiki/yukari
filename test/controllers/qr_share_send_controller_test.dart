import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:yukari/controllers/qr_share_send_controller.dart';
import 'package:yukari/share/share_document.dart';

import '../share/share_fixture.dart';

QrShareSendController controllerFor(
  ShareDocument document, {
  double refreshRate = 60,
}) {
  final controller = QrShareSendController(
    document: document,
    refreshRate: refreshRate,
    random: Random(7),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('defaultShareFps paces evenly on the display it reads', () {
    expect(defaultShareFps(60), 15);
    expect(defaultShareFps(59.94), 15);
    expect(defaultShareFps(90), 15);
    expect(defaultShareFps(120), 24);
    expect(defaultShareFps(144), 24);
    expect(defaultShareFps(240), 24);
  });

  test('defaultShareFps falls back to 15 without a usable rate', () {
    expect(defaultShareFps(0), 15);
    expect(defaultShareFps(-60), 15);
    expect(defaultShareFps(double.nan), 15);
    expect(defaultShareFps(double.infinity), 15);
  });

  test('the constructor publishes the first frame', () {
    final controller = controllerFor(sharedNetworkDocument());

    expect(controller.frame.value, isNotNull);
    expect(controller.framesSent.value, 1);
    expect(controller.blockCount.value, greaterThanOrEqualTo(1));
    expect(controller.payloadBytes.value, greaterThan(0));
    expect(controller.playing.value, isFalse);
    expect(controller.density.value, QrShareDensity.easy);
    expect(controller.fps.value, 15);
  });

  test('the document round-trips through a qrs receive session', () {
    final document = sharedNetworkDocument();
    final controller = controllerFor(document);
    final receiver = ReceiveSession();

    final limit = controller.blockCount.value * 4 + 20;
    for (var frame = 0; frame < limit && !receiver.isComplete; frame++) {
      receiver.addScan(controller.session.next().payload);
    }

    expect(receiver.isComplete, isTrue);
    final result = receiver.result!;
    expect(result.meta.contentType, shareContentType);
    expect(utf8.decode(result.data), document.encode());
  });

  /// The blocks Easy, Balanced and Fast need for [document].
  List<int> blocksPerDensity(ShareDocument document) {
    final controller = controllerFor(document);
    final easy = controller.blockCount.value;
    controller.updateDensity(QrShareDensity.balanced);
    final balanced = controller.blockCount.value;
    controller.updateDensity(QrShareDensity.fast);
    return [easy, balanced, controller.blockCount.value];
  }

  test('a node share keeps the three presets distinct', () {
    expect(blocksPerDensity(sharedNodeDocument()), [
      3,
      2,
      1,
    ], reason: 'the compressed node share is split 3, 2 and 1 ways');
  });

  test('an 8-peer network share splits 3, 2 and 1 ways', () {
    expect(blocksPerDensity(largeShareDocument()), [3, 2, 1]);
  });

  test('a share over 1 KiB keeps Fast at more than one code', () {
    final blocks = blocksPerDensity(hugeShareDocument());

    expect(blocks, [
      6,
      3,
      2,
    ], reason: 'the slice caps keep the QR versions sane');
    expect(blocks[2], greaterThan(1), reason: 'one QR cannot carry this much');
  });

  test('updateFps clamps to the allowed frame rate range', () {
    final controller = controllerFor(sharedNetworkDocument());

    controller.updateFps(1000);
    expect(controller.fps.value, maxShareFps);
    controller.updateFps(-4);
    expect(controller.fps.value, minShareFps);
    controller.updateFps(12);
    expect(controller.fps.value, 12);
  });

  testWidgets('updateDensity restarts the transfer with a new block size', (
    tester,
  ) async {
    final controller = controllerFor(largeShareDocument());
    expect(
      controller.blockCount.value,
      3,
      reason: 'the default Easy block size for this document',
    );

    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.framesSent.value, greaterThan(1));

    controller.updateDensity(QrShareDensity.fast);

    expect(controller.density.value, QrShareDensity.fast);
    expect(controller.blockCount.value, 1);
    expect(
      controller.framesSent.value,
      1,
      reason: 'the preview frame is the first',
    );
    expect(
      controller.playing.value,
      isTrue,
      reason: 'the restart keeps playing',
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.framesSent.value, greaterThan(1));
    controller.pause();
  });

  testWidgets('a paused stream publishes no frame', (tester) async {
    final controller = controllerFor(sharedNetworkDocument());
    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    controller.pause();
    final sent = controller.framesSent.value;

    await tester.pump(const Duration(seconds: 1));

    expect(controller.framesSent.value, sent);
  });

  testWidgets('dispose cancels the frame loop', (tester) async {
    final controller = QrShareSendController(
      document: sharedNetworkDocument(),
      refreshRate: 60,
      random: Random(7),
    );
    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.framesSent.value, greaterThan(1));

    controller.dispose();
    // A frame timer that survived dispose would still be pending when the
    // binding checks for timers at the end of the widget test, failing it.
    await tester.pump(const Duration(seconds: 1));
  });

  test('exportGif pauses the stream and encodes every frame', () async {
    final controller = controllerFor(sharedNetworkDocument());
    controller.play();
    expect(controller.playing.value, isTrue);

    final bytes = await controller.exportGif();

    expect(
      controller.playing.value,
      isFalse,
      reason: 'the export owns the isolate while it runs',
    );
    expect(controller.gifFrameCount, controller.blockCount.value + 4);
    expect(bytes, isNotNull);
    expect(ascii.decode(bytes!.sublist(0, 6)), startsWith('GIF8'));
    expect(controller.exported.value, controller.gifFrameCount);
    expect(controller.exporting.peek(), isFalse);
  });

  test('cancelExport aborts the running GIF export', () async {
    final controller = controllerFor(sharedNetworkDocument());

    final export = controller.exportGif();
    controller.cancelExport();

    expect(await export, isNull);
    expect(controller.exporting.peek(), isFalse);
  });
}

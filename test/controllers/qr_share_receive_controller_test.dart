import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:yukari/controllers/qr_share_receive_controller.dart';
import 'package:yukari/share/image_qr_scan.dart';
import 'package:yukari/share/share_bundle.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_import.dart';
import 'package:yukari/signals/locale.dart' as app;

import '../share/share_fixture.dart';

/// A sender for [content], built the way the share page builds one.
SendSession senderForContent(
  String content, {
  int sliceSize = 200,
  bool compress = false,
}) => SendSession.forFile(
  Uint8List.fromList(utf8.encode(content)),
  filename: 'share.json',
  contentType: shareContentType,
  sliceSize: sliceSize,
  compress: compress,
);

/// A sender for [document], built the way the share page builds one.
SendSession senderFor(ShareDocument document, {int sliceSize = 200}) =>
    senderForContent(document.encode(), sliceSize: sliceSize);

/// A sender of a file that is not a Yukari share.
SendSession foreignSender({String contentType = 'text/plain'}) =>
    SendSession.forFile(
      Uint8List.fromList(utf8.encode('not a yukari share')),
      filename: 'note.txt',
      contentType: contentType,
      sliceSize: 100,
      compress: false,
    );

/// An image scanner that reports [payloads] and optionally fails.
ImageScanner fakeScanner({List<String> payloads = const [], Object? error}) =>
    (
      Uint8List bytes, {
      void Function(int done, int total)? onProgress,
      void Function(String payload)? onPayload,
      bool Function()? isCancelled,
    }) async {
      final total = payloads.length + 1;
      onProgress?.call(0, total);
      for (final payload in payloads) {
        if (isCancelled?.call() ?? false) break;
        onPayload?.call(payload);
      }
      if (error != null) throw error;
      onProgress?.call(total, total);
      return ImageScanReport(frames: 1, payloads: payloads);
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> messages;
  late int now;

  setUp(() {
    messages = <String>[];
    now = 0;
  });

  /// A controller whose every dependency the test owns.
  QrShareReceiveController create({
    ShareImporter? importer,
    ImageScanner? imageScanner,
  }) {
    final controller = QrShareReceiveController(
      cameraAvailable: false,
      importer: importer ?? ShareImporter.defaults,
      showMessage: messages.add,
      imageScanner: imageScanner ?? fakeScanner(),
      nowMicros: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// Feeds [sender]'s frames until the controller has a share or an error.
  void feedUntilSettled(
    QrShareReceiveController controller,
    SendSession sender,
  ) {
    var guard = sender.blockCount * 60;
    while (controller.shares.value.isEmpty && controller.error.value == null) {
      expect(guard--, greaterThan(0), reason: 'the transfer never settled');
      controller.addPayload(sender.next().payload);
      now += 100000;
    }
  }

  test('only Android has a camera scanner', () {
    expect(platformHasCamera(), Platform.isAndroid);
  });

  test('feeds frames into the session and completes a share', () {
    final controller = create();
    final document = sharedNetworkDocument();
    final sender = senderFor(document);
    final k = sender.blockCount;
    expect(k, greaterThan(1), reason: 'the fixture must need several frames');
    expect(controller.pace.value, ScanPace.balanced);

    expect(controller.addPayload(sender.next().payload), ScanOutcome.started);
    expect(controller.k.value, k);
    expect(controller.frames.value, 1);
    expect(controller.status.value, hasLength(k));
    expect(controller.status.value.where((status) => status > 0), isNotEmpty);
    expect(controller.error.value, isNull);

    feedUntilSettled(controller, sender);

    expect(controller.error.value, isNull);
    expect(controller.shares.value.single.encode(), document.encode());
    expect(controller.decoded.value, k);
    expect(controller.frames.value, greaterThanOrEqualTo(k));
    // The transfer froze its average once it finished.
    expect(controller.speed.value, greaterThan(0));
  });

  test('a bundle payload decodes to every document it carries', () {
    final controller = create();
    final sender = senderForContent(
      encodeShareItems([networkShare('alpha'), networkShare('beta')]),
      sliceSize: 1000,
    );
    expect(sender.blockCount, 1);

    feedUntilSettled(controller, sender);

    expect(controller.error.value, isNull);
    expect(controller.shares.value.map((document) => document.name), [
      'alpha',
      'beta',
    ]);
  });

  test('an oversize payload is refused before it is decoded', () {
    final controller = create();
    // Valid apart from its size, and compressed on the wire so the transfer
    // itself stays one frame: the guard is about what the receiver decodes.
    final padded = jsonEncode({
      ...sharedNodeDocument().toJson(),
      'padding': 'x' * shareMaxBytes,
    });
    final sender = senderForContent(padded, sliceSize: 1000, compress: true);

    feedUntilSettled(controller, sender);

    expect(controller.shares.value, isEmpty);
    expect(controller.error.value, app.l10n.value.shareReceiveInvalid);
  });

  test('duplicate frames do not advance the transfer', () {
    final controller = create();
    final sender = senderFor(sharedNetworkDocument());
    final payload = sender.next().payload;
    controller.addPayload(payload);
    final frames = controller.frames.value;
    final decoded = controller.decoded.value;

    expect(controller.addPayload(payload), ScanOutcome.duplicate);
    expect(controller.frames.value, frames);
    expect(controller.decoded.value, decoded);
    // A repeated frame is not an error: the camera sees it constantly.
    expect(controller.error.value, isNull);
  });

  test('empty and malformed payloads stay silent', () {
    final controller = create();

    expect(controller.addPayload(null), ScanOutcome.empty);
    expect(controller.addPayload(''), ScanOutcome.empty);
    expect(controller.addPayload('not a fountain frame'), ScanOutcome.invalid);
    expect(controller.error.value, isNull);
    expect(controller.k.value, 0);
  });

  test('a transfer with a foreign content type yields no share', () {
    final controller = create();

    feedUntilSettled(controller, foreignSender());

    expect(controller.shares.value, isEmpty);
    expect(controller.error.value, app.l10n.value.shareReceiveInvalid);
  });

  test('a share that does not decode is reported as invalid', () {
    final controller = create();
    final sender = foreignSender(contentType: shareContentType);

    feedUntilSettled(controller, sender);

    expect(controller.shares.value, isEmpty);
    expect(controller.error.value, app.l10n.value.shareReceiveInvalid);
  });

  test('a different share mid-transfer restarts the transfer', () {
    final controller = create();
    final first = senderFor(sharedNetworkDocument());
    expect(first.blockCount, 2, reason: 'one frame must stay incomplete');
    controller.addPayload(first.next().payload);
    expect(controller.frames.value, 1);
    expect(controller.shares.value, isEmpty);

    final other = senderFor(sharedNodeDocument(), sliceSize: 50);
    expect(other.blockCount, greaterThan(1));
    controller.addPayload(other.next().payload);

    expect(messages, <String>[app.l10n.value.shareReceiveDifferentShare]);
    expect(controller.frames.value, 1);
    expect(controller.k.value, other.blockCount);
    expect(controller.shares.value, isEmpty);

    feedUntilSettled(controller, other);
    expect(controller.shares.value.single.kind, ShareKind.node);
    // The message is said once, not for every frame of the new transfer.
    expect(messages, hasLength(1));
  });

  test('an image scan feeds its payloads and reports progress', () async {
    final document = sharedNodeDocument();
    final sender = senderFor(document, sliceSize: 1000);
    expect(sender.blockCount, 1);
    final payload = sender.next().payload;

    late QrShareReceiveController controller;
    final seen = <({int done, int total})?>[];
    controller = create(
      imageScanner:
          (
            Uint8List bytes, {
            void Function(int done, int total)? onProgress,
            void Function(String payload)? onPayload,
            bool Function()? isCancelled,
          }) async {
            onProgress?.call(1, 3);
            seen.add(controller.imageProgress.value);
            onPayload?.call(payload);
            onProgress?.call(3, 3);
            return const ImageScanReport(frames: 1, payloads: []);
          },
    );

    await controller.scanImage(Uint8List.fromList(<int>[1, 2, 3]));

    expect(seen, <({int done, int total})>[(done: 1, total: 3)]);
    expect(controller.shares.value.single.encode(), document.encode());
    expect(controller.imageProgress.value, isNull);
    expect(controller.error.value, isNull);
  });

  test('an image without a QR code is reported', () async {
    final controller = create();

    await controller.scanImage(Uint8List.fromList(<int>[1, 2, 3]));

    expect(controller.error.value, app.l10n.value.shareReceiveImageEmpty);
    expect(controller.imageProgress.value, isNull);
  });

  test('an image that cannot be read is reported', () async {
    final controller = create(
      imageScanner: fakeScanner(error: const FormatException('bad image')),
    );

    await controller.scanImage(Uint8List.fromList(<int>[1, 2, 3]));

    expect(
      controller.error.value,
      app.l10n.value.shareReceiveImageFailed('FormatException: bad image'),
    );
    expect(controller.imageProgress.value, isNull);
  });

  test('ignores a second image scan while one runs', () async {
    final gate = Completer<void>();
    var scans = 0;
    final controller = create(
      imageScanner:
          (
            Uint8List bytes, {
            void Function(int done, int total)? onProgress,
            void Function(String payload)? onPayload,
            bool Function()? isCancelled,
          }) async {
            scans++;
            await gate.future;
            return const ImageScanReport(frames: 1, payloads: []);
          },
    );

    final first = controller.scanImage(Uint8List.fromList(<int>[1]));
    await controller.scanImage(Uint8List.fromList(<int>[2]));
    expect(scans, 1);

    gate.complete();
    await first;
    expect(controller.error.value, app.l10n.value.shareReceiveImageEmpty);
  });

  test('saving a network adds it once and reports its name', () async {
    final added = <ShareDocument>[];
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async {
          added.add(document);
          return 'alpha (2)';
        },
        addNode: (document) async => fail('a network is not saved as a node'),
      ),
    );
    controller.shares.value = [sharedNetworkDocument()];

    expect(await controller.save(), isTrue);
    expect(added, hasLength(1));
    expect(messages, <String>[
      app.l10n.value.shareReceiveNetworkAdded('alpha (2)'),
    ]);
    expect(controller.saved.value, isTrue);
    expect(controller.saving.value, isFalse);

    // A second tap must not add the network again.
    expect(await controller.save(), isFalse);
    expect(added, hasLength(1));
    expect(messages, hasLength(1));
  });

  test('saving a node reports its address', () async {
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async =>
            fail('a node is not saved as a network'),
        addNode: (document) async => 'relay.example.com:11010',
      ),
    );
    controller.shares.value = [sharedNodeDocument()];

    expect(await controller.save(), isTrue);
    expect(messages, <String>[
      app.l10n.value.shareReceiveNodeSaved('relay.example.com:11010'),
    ]);
    expect(controller.saved.value, isTrue);
  });

  test('saving a node that is already bookmarked says so', () async {
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async =>
            fail('a node is not saved as a network'),
        addNode: (document) async => null,
      ),
    );
    controller.shares.value = [sharedNodeDocument()];

    expect(await controller.save(), isTrue);
    expect(messages, <String>[app.l10n.value.shareReceiveNodeExists]);
    expect(controller.saved.value, isTrue);
  });

  test('adding a bundle says how many arrived', () async {
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async => document.name!,
        addNode: (document) async => fail('no node is in this bundle'),
      ),
    );
    controller.shares.value = [networkShare('alpha'), networkShare('beta')];

    expect(await controller.save(), isTrue);
    expect(messages, <String>[app.l10n.value.shareReceiveAddedAll(2)]);
    expect(controller.saved.value, isTrue);

    // A saved bundle is spent: a second tap must not add it again.
    expect(await controller.save(), isFalse);
    expect(messages, hasLength(1));
  });

  test('adding a bundle reports the duplicates and failures it hit', () async {
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async {
          if (document.name == 'beta') throw StateError('disk');
          return document.name!;
        },
        addNode: (document) async => fail('no node is in this bundle'),
      ),
    );
    controller.shares.value = [networkShare('alpha'), networkShare('beta')];

    expect(await controller.save(), isTrue);
    expect(messages, <String>[
      app.l10n.value.shareReceiveAddSummary(1, 0, 1),
    ]);
  });

  test('a failed save is reported and can be retried', () async {
    var attempts = 0;
    final controller = create(
      importer: ShareImporter(
        addNetwork: (document) async {
          attempts++;
          throw StateError('disk');
        },
        addNode: (document) async => null,
      ),
    );
    controller.shares.value = [sharedNetworkDocument()];

    expect(await controller.save(), isFalse);
    expect(messages, <String>[
      app.l10n.value.shareReceiveAddFailed('Bad state: disk'),
    ]);
    expect(controller.saved.value, isFalse);
    expect(controller.saving.value, isFalse);

    expect(await controller.save(), isFalse);
    expect(attempts, 2);
  });

  test('saving without a share does nothing', () async {
    final controller = create();

    expect(await controller.save(), isFalse);
    expect(messages, isEmpty);
  });

  test('reset forgets the transfer and the saved state', () {
    final controller = create();
    final sender = senderFor(sharedNetworkDocument());
    controller.addPayload(sender.next().payload);
    controller.addPayload(sender.next().payload);
    controller.shares.value = [sharedNodeDocument()];
    controller.saved.value = true;
    controller.error.value = 'stale';

    controller.reset();

    expect(controller.k.value, 0);
    expect(controller.decoded.value, 0);
    expect(controller.frames.value, 0);
    expect(controller.status.value, isEmpty);
    expect(controller.shares.value, isEmpty);
    expect(controller.error.value, isNull);
    expect(controller.speed.value, 0);
    expect(controller.saved.value, isFalse);
  });

  test('dispose stops the controller and is idempotent', () async {
    final controller = create();
    final sender = senderFor(sharedNetworkDocument());
    controller.addPayload(sender.next().payload);

    controller.dispose();
    controller.dispose();

    expect(controller.addPayload(sender.next().payload), ScanOutcome.empty);
    expect(await controller.save(), isFalse);
    await controller.scanImage(Uint8List.fromList(<int>[1]));
  });
}

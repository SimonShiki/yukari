import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari/controllers/qr_share_receive_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/share/qr_share_receive_page.dart';
import 'package:yukari/pages/share/widgets/block_grid.dart';
import 'package:yukari/pages/share/widgets/camera_scanner_card.dart';
import 'package:yukari/pages/share/widgets/receive_progress_card.dart';
import 'package:yukari/share/image_qr_scan.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_import.dart';
import 'package:yukari/signals/networks.dart' as networks;
import 'package:yukari/widgets/snackbar/app_snackbar.dart';

import '../networks_fixture.dart';
import '../share/share_fixture.dart';

/// The one frame a one-block share is sent as, the way the share page builds
/// it.
String sharePayload(ShareDocument document) => SendSession.forFile(
  Uint8List.fromList(utf8.encode(document.encode())),
  filename: 'share.json',
  contentType: shareContentType,
  sliceSize: 1000,
  compress: false,
).next().payload;

/// An image scanner that feeds [payload] to the receiver.
ImageScanner scannerFinding(String payload) =>
    (
      Uint8List bytes, {
      void Function(int done, int total)? onProgress,
      void Function(String payload)? onPayload,
      bool Function()? isCancelled,
    }) async {
      onProgress?.call(1, 1);
      onPayload?.call(payload);
      return ImageScanReport(frames: 1, payloads: [payload]);
    };

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  late List<String> messages;
  late BuildContext snackBarContext;

  setUp(() => messages = <String>[]);

  /// The painter behind [BlockGrid]'s single [CustomPaint].
  CustomPainter gridPainter(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(BlockGrid),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter!;

  /// Pumps the receive page with a controller whose dependencies the test owns.
  Future<QrShareReceiveController> pumpPage(
    WidgetTester tester, {
    bool cameraAvailable = false,
    Widget Function(BuildContext context, ScanPace pace)? cameraBuilder,
    ImageScanner? imageScanner,
    ShareImporter? importer,
    Future<Uint8List?> Function()? pickImage,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = QrShareReceiveController(
      cameraAvailable: cameraAvailable,
      importer: importer ?? ShareImporter.defaults,
      showMessage: (message) {
        messages.add(message);
        showAppSnackBar(snackBarContext, message);
      },
      imageScanner: imageScanner ?? scannerFinding('no payload'),
      nowMicros: () => 0,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            snackBarContext = context;
            return QrShareReceivePage(
              controller: controller,
              cameraBuilder: cameraBuilder,
              pickImage: pickImage,
            );
          },
        ),
      ),
    );
    return controller;
  }

  test('maps the scan pace to a camera detection speed', () {
    expect(detectionSpeedFor(ScanPace.relaxed), DetectionSpeed.normal);
    expect(detectionSpeedFor(ScanPace.balanced), DetectionSpeed.noDuplicates);
    expect(detectionSpeedFor(ScanPace.turbo), DetectionSpeed.unrestricted);
  });

  testWidgets('a platform without a camera falls back to images', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text(strings.shareReceiveNoCamera), findsOneWidget);
    // One image-scan action for the whole page, in the progress card.
    expect(find.text(strings.shareReceiveScanImage), findsOneWidget);
    // The scan-rate selector only applies where a camera exists.
    expect(find.text(strings.shareReceiveScanRate), findsNothing);
    expect(find.text(strings.shareReceiveWaiting), findsOneWidget);
    expect(find.text(strings.shareReceiveFrames(0)), findsOneWidget);
    expect(find.text(strings.shareReceiveSpeed), findsOneWidget);
    expect(find.text('0 B/s'), findsOneWidget);
    // No plugin widget is ever built by the test.
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.byType(CameraScannerCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a camera platform shows the preview and the rate selector', (
    tester,
  ) async {
    final controller = await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) =>
          const SizedBox(width: 40, height: 40, child: Text('camera stub')),
    );

    expect(find.text('camera stub'), findsOneWidget);
    expect(find.text(strings.shareReceiveNoCamera), findsNothing);
    expect(find.text(strings.shareReceiveScanRate), findsOneWidget);
    expect(find.text(strings.shareReceiveRateRelaxed), findsOneWidget);
    expect(find.text(strings.shareReceiveRateHint), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);

    await tester.tap(find.text(strings.shareReceiveRateTurbo));
    await tester.pump();

    expect(controller.pace.value, ScanPace.turbo);
  });

  testWidgets('the progress card follows the transfer signals', (tester) async {
    final controller = await pumpPage(tester);
    expect(find.byType(BlockGrid), findsNothing);

    controller.k.value = 5;
    controller.decoded.value = 2;
    controller.frames.value = 7;
    controller.speed.value = 1024;
    controller.status.value = const [1, 1, 0, 0, 0];
    await tester.pump();

    expect(find.text(strings.shareReceiveProgress(2, 5)), findsOneWidget);
    expect(find.text(strings.shareReceiveFrames(7)), findsOneWidget);
    expect(find.text(strings.shareReceiveWaiting), findsNothing);
    expect(find.text('1.0 KB/s'), findsOneWidget);
    expect(find.byType(BlockGrid), findsOneWidget);
    final indicator = tester.widget<M3ELinearWavyProgressIndicator>(
      find.byType(M3ELinearWavyProgressIndicator),
    );
    expect(indicator.value, 0.4);

    // A newly decoded block repaints the grid.
    final before = gridPainter(tester);
    controller.status.value = const [1, 1, 1, 0, 0];
    await tester.pump();
    expect(gridPainter(tester).shouldRepaint(before), isTrue);
  });

  testWidgets('the scan rate re-keys the camera card', (tester) async {
    final paces = <ScanPace>[];
    final controller = await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) {
        paces.add(pace);
        return const SizedBox.shrink();
      },
    );
    expect(paces, <ScanPace>[ScanPace.balanced]);

    await tester.tap(find.text(strings.shareReceiveRateTurbo));
    await tester.pump();

    expect(controller.pace.value, ScanPace.turbo);
    // Only a builder call with the new pace proves the card would re-key.
    expect(paces.last, ScanPace.turbo);
  });

  testWidgets('the camera pane ignores progress updates', (tester) async {
    var builds = 0;
    final controller = await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) {
        builds++;
        return const SizedBox.shrink();
      },
    );
    final initial = builds;

    controller.k.value = 4;
    controller.decoded.value = 1;
    controller.frames.value = 2;
    controller.status.value = const [1, 0, 0, 0];
    controller.speed.value = 2048;
    await tester.pump();

    // Progress is the progress card's business: the camera pane is not rebuilt.
    expect(builds, initial);
    expect(find.text(strings.shareReceiveProgress(1, 4)), findsOneWidget);
    expect(find.text('2.0 KB/s'), findsOneWidget);
  });

  testWidgets('the app bar resets a transfer that started', (tester) async {
    final controller = await pumpPage(tester);
    expect(find.byTooltip(strings.shareReceiveScanAnother), findsNothing);

    controller.k.value = 3;
    controller.decoded.value = 1;
    controller.frames.value = 2;
    await tester.pump();
    expect(find.byTooltip(strings.shareReceiveScanAnother), findsOneWidget);

    await tester.tap(find.byTooltip(strings.shareReceiveScanAnother));
    await tester.pump();

    expect(controller.k.value, 0);
    expect(controller.frames.value, 0);
    expect(find.text(strings.shareReceiveWaiting), findsOneWidget);
  });

  testWidgets('the completed network can be added', (tester) async {
    final added = <ShareDocument>[];
    final controller = await pumpPage(
      tester,
      importer: ShareImporter(
        addNetwork: (document) async {
          added.add(document);
          return 'alpha (2)';
        },
        addNode: (document) async => 'relay.example.com:11010',
      ),
    );

    controller.share.value = sharedNetworkDocument();
    await tester.pump();

    expect(find.text(strings.shareReceiveComplete), findsOneWidget);
    expect(find.text(strings.shareKindNetwork), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text(strings.sharePreviewPeers), findsOneWidget);
    expect(find.text(strings.sharePreviewProtocols), findsOneWidget);
    expect(find.text(strings.sharePreviewSecret), findsOneWidget);
    expect(find.text(strings.sharePreviewSecretIncluded), findsOneWidget);
    // The network secret itself is never shown.
    expect(find.text('s3cret'), findsNothing);
    // The preview replaces the transfer.
    expect(find.byType(ReceiveProgressCard), findsNothing);
    expect(find.byType(BlockGrid), findsNothing);

    await tester.tap(find.text(strings.shareReceiveAddNetwork));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(messages, <String>[strings.shareReceiveNetworkAdded('alpha (2)')]);
    expect(
      find.text(strings.shareReceiveNetworkAdded('alpha (2)')),
      findsOneWidget,
    );
    expect(controller.saved.value, isTrue);
    // The action is spent once the network is added.
    final button = tester.widget<M3EButton>(
      find.ancestor(
        of: find.text(strings.shareReceiveAddNetwork),
        matching: find.byType(M3EButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the completed node can be saved', (tester) async {
    final saved = <ShareDocument>[];
    final controller = await pumpPage(
      tester,
      importer: ShareImporter(
        addNetwork: (document) async => fail('a node is not a network'),
        addNode: (document) async {
          saved.add(document);
          return 'relay.example.com:11010';
        },
      ),
    );

    controller.share.value = sharedNodeDocument();
    await tester.pump();

    expect(find.text(strings.shareKindNode), findsOneWidget);
    // The headline is the address; the details do not repeat it.
    expect(find.text('relay.example.com:11010'), findsOneWidget);
    expect(find.text(strings.sharePreviewProtocols), findsOneWidget);

    await tester.tap(find.text(strings.shareReceiveSaveNode));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(messages, <String>[
      strings.shareReceiveNodeSaved('relay.example.com:11010'),
    ]);
    expect(controller.saved.value, isTrue);
  });

  testWidgets('an invalid share shows the error and a way out', (tester) async {
    final controller = await pumpPage(tester);

    controller.error.value = strings.shareReceiveInvalid;
    await tester.pump();

    expect(find.text(strings.shareReceiveInvalid), findsOneWidget);

    await tester.tap(find.text(strings.shareReceiveScanAnother));
    await tester.pump();

    expect(controller.error.value, isNull);
    expect(find.text(strings.shareReceiveInvalid), findsNothing);
  });

  testWidgets('a picked image is scanned into the preview', (tester) async {
    final document = sharedNodeDocument();
    final controller = await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) => const SizedBox.shrink(),
      pickImage: () async => Uint8List.fromList(<int>[1, 2, 3]),
      imageScanner: scannerFinding(sharePayload(document)),
    );

    await tester.tap(find.text(strings.shareReceiveScanImage));
    await tester.pump();
    await tester.pump();

    expect(controller.share.value?.encode(), document.encode());
    expect(find.text(strings.shareReceiveComplete), findsOneWidget);
    expect(find.text(strings.shareReceiveSaveNode), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('an image scan with no known frame count is indeterminate', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) => const SizedBox.shrink(),
      pickImage: () async => Uint8List.fromList(<int>[1]),
      imageScanner:
          (
            Uint8List bytes, {
            void Function(int done, int total)? onProgress,
            void Function(String payload)? onPayload,
            bool Function()? isCancelled,
          }) async {
            await gate.future;
            return const ImageScanReport(frames: 0, payloads: []);
          },
    );

    await tester.tap(find.text(strings.shareReceiveScanImage));
    await tester.pump();
    await tester.pump();

    // The frame count is unknown, so no "frame 0 of 0" text is shown.
    expect(find.text(strings.shareReceiveImageScanning(0, 0)), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the image scan reports its progress', (tester) async {
    final gate = Completer<void>();
    final controller = await pumpPage(
      tester,
      cameraAvailable: true,
      cameraBuilder: (context, pace) => const SizedBox.shrink(),
      pickImage: () async => Uint8List.fromList(<int>[1, 2, 3]),
      imageScanner:
          (
            Uint8List bytes, {
            void Function(int done, int total)? onProgress,
            void Function(String payload)? onPayload,
            bool Function()? isCancelled,
          }) async {
            onProgress?.call(1, 4);
            await gate.future;
            return const ImageScanReport(frames: 1, payloads: []);
          },
    );

    await tester.tap(find.text(strings.shareReceiveScanImage));
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.shareReceiveImageScanning(1, 4)), findsOneWidget);
    expect(controller.imageProgress.value, (done: 1, total: 4));

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.shareReceiveImageScanning(1, 4)), findsNothing);
    expect(controller.error.value, strings.shareReceiveImageEmpty);
    expect(find.text(strings.shareReceiveImageEmpty), findsOneWidget);
  });

  /// The share as a camera-less receiver sees it: one QR frame rendered as a
  /// black-on-white PNG.
  Uint8List sharePng(ShareDocument document) {
    final frame = SendSession.forFile(
      Uint8List.fromList(utf8.encode(document.encode())),
      filename: 'share.json',
      contentType: shareContentType,
      sliceSize: 1000,
      compress: false,
    ).next();
    const scale = 5;
    final matrix = frame.qr.data;
    final side = matrix.length * scale;
    final image = img.Image(width: side, height: side);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final black = img.ColorRgb8(0, 0, 0);
    for (var y = 0; y < matrix.length; y++) {
      for (var x = 0; x < matrix[y].length; x++) {
        if (!matrix[y][x]) continue;
        img.fillRect(
          image,
          x1: x * scale,
          y1: y * scale,
          x2: x * scale + scale - 1,
          y2: y * scale + scale - 1,
          color: black,
        );
      }
    }
    return img.encodePng(image);
  }

  testWidgets('the production page reports the added network', (tester) async {
    // The page-owned controller reads the platform table, so this is the
    // camera-less production path: real controller, real importer, real store,
    // and only the picker replaced with an image.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.runAsync(() async {
        await seedWith(<String, Network>{});
        final png = sharePng(sharedNetworkDocument());

        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: QrShareReceivePage(pickImage: () async => png),
          ),
        );

        await tester.tap(find.text(strings.shareReceiveScanImage));
        // The real worker isolate decodes the PNG; runAsync lets it finish.
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text(strings.shareReceiveComplete).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text(strings.shareReceiveComplete), findsOneWidget);

        await tester.tap(find.text(strings.shareReceiveAddNetwork));
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await networks.settled();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // The page-owned controller's message sink is what regressed: the
        // production path must show the outcome, not drop it.
        expect(
          find.text(strings.shareReceiveNetworkAdded('alpha')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

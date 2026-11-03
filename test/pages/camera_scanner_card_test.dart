import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yukari/controllers/qr_share_receive_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/share/widgets/camera_scanner_card.dart';

/// The three channels the method-channel scanner implementation uses.
const _methodChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);
const _eventChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);
const _orientationChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

/// Serves the camera channels the way the Android plugin does, and records
/// every method the card calls on them.
///
/// The [ScanPace] ordering itself is locked in `camera_scanner_session_test`:
/// a debug build force-stops the platform before it starts, which hides the
/// release race this card has to survive, so no debug-build test can reproduce
/// it.
void mockScannerChannels(List<String> calls) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const viewConfiguration = <String, Object?>{
    'textureId': 1,
    'cameraDirection': 1,
    'numberOfCameras': 2,
    'currentTorchState': 0,
    'size': <String, Object?>{'width': 1280.0, 'height': 720.0},
    'handlesCropAndRotation': true,
    'naturalDeviceOrientation': 'PORTRAIT_UP',
    'sensorOrientation': 90,
  };

  messenger.setMockMethodCallHandler(_methodChannel, (call) async {
    calls.add(call.method);
    return switch (call.method) {
      // Authorized, so the plugin never asks for the permission.
      'state' => 1,
      'start' => viewConfiguration,
      _ => null,
    };
  });
  // The event channels only need an implementation: a missing one is reported
  // as a Flutter error.
  for (final channel in [_eventChannel, _orientationChannel]) {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QrShareReceiveController controller;

  setUp(() {
    // The plugin keeps the camera session owner in a static.
    MobileScannerController.resetPlatformSessionOwner();
    controller = QrShareReceiveController(
      cameraAvailable: true,
      showMessage: (_) {},
    );
    addTearDown(controller.dispose);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      _methodChannel,
      _eventChannel,
      _orientationChannel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    MobileScannerController.resetPlatformSessionOwner();
  });

  /// Pumps the same card at [pace], so a second call is a pace change of the
  /// card already on screen rather than a new one.
  Future<void> pumpCard(WidgetTester tester, ScanPace pace) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CameraScannerCard(controller: controller, pace: pace),
        ),
      ),
    );
  }

  testWidgets('a pace change swaps the scanner without a camera error', (
    tester,
  ) async {
    final calls = <String>[];
    mockScannerChannels(calls);

    await pumpCard(tester, ScanPace.balanced);
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(calls.where((call) => call == 'start'), hasLength(1));

    await pumpCard(tester, ScanPace.turbo);
    await tester.pumpAndSettle();

    expect(find.byType(MobileScanner), findsOneWidget);
    expect(calls.where((call) => call == 'start'), hasLength(2));
    // The plugin reports a camera it cannot take as an error pane; the swap
    // must not reach for the camera the old scanner still holds.
    expect(find.textContaining('controllerAlreadyInitialized'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the page releases the camera', (tester) async {
    final calls = <String>[];
    mockScannerChannels(calls);

    await pumpCard(tester, ScanPace.balanced);
    await tester.pumpAndSettle();
    expect(calls, contains('start'));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(calls, contains('stop'));
    // A stopped camera is a camera the next page can have.
    expect(calls.last, 'stop');
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yukari/controllers/qr_share_receive_controller.dart';
import 'package:yukari/pages/share/widgets/camera_scanner_session.dart';

/// The camera texture `MobileScannerPlatform` holds for the whole process, in
/// the three ways the session can tell it apart: `start()` fails while it is
/// taken, `stop()` releases it at once, and `dispose()` only releases it after
/// an awaited method-channel round trip.
class _FakeCamera {
  /// The platform calls the scanners made, in order.
  final List<String> calls = <String>[];

  /// The scanners the session built, in creation order.
  final List<_FakeScanner> scanners = <_FakeScanner>[];

  /// Whether the camera texture is taken.
  bool held = false;

  /// Makes the next platform disposes fail, the way a camera the platform lost
  /// does — after the texture is released and without closing anything else.
  bool throwOnDispose = false;

  _FakeScanner create(ScanPace pace) {
    final scanner = _FakeScanner(this, pace);
    scanners.add(scanner);
    return scanner;
  }

  void start(ScanPace pace) {
    calls.add('start ${pace.name}');
    if (held) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerAlreadyInitialized,
      );
    }
    held = true;
  }

  void stop(ScanPace pace) {
    calls.add('stop ${pace.name}');
    held = false;
  }

  Future<void> dispose(ScanPace pace) async {
    calls.add('dispose ${pace.name}');
    await Future<void>.value();
    held = false;
    if (throwOnDispose) throw StateError('the platform refused to dispose');
  }
}

class _FakeScanner extends MobileScannerController {
  _FakeScanner(this._camera, this.pace) : super(autoStart: false);

  final _FakeCamera _camera;

  /// The pace the session built this scanner for.
  final ScanPace pace;

  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    try {
      _camera.start(pace);
      value = value.copyWith(isInitialized: true, isRunning: true);
    } on MobileScannerException catch (error) {
      // The controller records a refused start in its state instead of
      // rethrowing; that state is what the preview renders as an error pane.
      value = value.copyWith(
        isInitialized: true,
        isRunning: false,
        error: error,
      );
    }
  }

  @override
  Future<void> stop() async {
    _camera.stop(pace);
    value = value.copyWith(isRunning: false);
  }

  @override
  Future<void> dispose() async {
    try {
      await _camera.dispose(pace);
    } finally {
      // The controller closes itself before it awaits the platform, so a
      // refused platform dispose still leaves it closed.
      await super.dispose();
    }
  }
}

void main() {
  late _FakeCamera camera;
  late CameraScannerSession session;

  setUp(() {
    camera = _FakeCamera();
    session = CameraScannerSession(camera.create, pace: ScanPace.balanced);
    addTearDown(session.dispose);
  });

  test('a pace change tears the previous scanner down before the next one '
      'starts', () async {
    await session.start();
    session.request(ScanPace.turbo);
    await session.settled;

    expect(camera.calls, <String>[
      'start balanced',
      'stop balanced',
      'dispose balanced',
      'start turbo',
    ]);
    expect(camera.scanners, hasLength(2));
    expect(session.scanner, same(camera.scanners.last));
    expect(camera.scanners.last.value.isRunning, isTrue);
    expect(camera.scanners.last.value.error, isNull);
    expect(camera.scanners.first.value.isRunning, isFalse);
    expect(camera.held, isTrue);
  });

  test('two quick pace changes build one scanner for the last pace', () async {
    await session.start();
    session.request(ScanPace.turbo);
    session.request(ScanPace.relaxed);
    await session.settled;

    expect(camera.calls, <String>[
      'start balanced',
      'stop balanced',
      'dispose balanced',
      'start relaxed',
    ]);
    expect(camera.scanners, hasLength(2));
    expect(camera.scanners.last.pace, ScanPace.relaxed);
    expect(camera.scanners.last.value.error, isNull);
  });

  test('dispose during a swap leaves no scanner and no live camera', () async {
    await session.start();
    session.request(ScanPace.turbo);
    await session.dispose();

    expect(session.scanner, isNull);
    expect(camera.scanners, hasLength(1));
    expect(camera.held, isFalse);
  });

  test('stop and start follow the scanner of the current pace', () async {
    await session.start();
    session.request(ScanPace.turbo);
    await session.settled;

    final turbo = camera.scanners.last;
    camera.calls.clear();

    await session.stop();
    await session.start();

    expect(camera.calls, <String>['stop turbo', 'start turbo']);
    expect(turbo.value.isRunning, isTrue);
  });

  test(
    'a refused teardown neither aborts the swap nor wedges the queue',
    () async {
      await session.start();
      camera.throwOnDispose = true;

      session.request(ScanPace.turbo);
      await session.settled;

      // The old scanner could not close cleanly, but it released the camera, so
      // the new pace still got its scanner.
      expect(camera.scanners, hasLength(2));
      expect(session.scanner, same(camera.scanners.last));
      expect(camera.scanners.last.pace, ScanPace.turbo);
      expect(camera.scanners.last.value.isRunning, isTrue);
      expect(camera.scanners.last.value.error, isNull);

      camera.throwOnDispose = false;
      await session.dispose();

      // The queue kept running behind the failure: dispose reached the camera.
      expect(session.scanner, isNull);
      expect(camera.held, isFalse);
    },
  );
}

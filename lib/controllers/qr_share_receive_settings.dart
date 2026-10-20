part of 'qr_share_receive_controller.dart';

/// How hard the camera card pushes the scanner.
///
/// Power against throughput: relaxed leaves 250 ms between attempts (the camera
/// keeps its exposure, the battery lasts), turbo removes the throttle.
enum ScanPace { relaxed, balanced, turbo }

/// Whether `mobile_scanner` ships a camera backend for this platform.
///
/// A pure platform table, not a plugin probe: the page explains the fallback
/// before the user taps anything, and Linux and Windows scan an image instead.
bool platformHasCamera() =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.linux ||
      TargetPlatform.windows ||
      TargetPlatform.fuchsia => false,
    };

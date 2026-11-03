import 'dart:async';

import 'package:flutter/widgets.dart';

import 'native_tray_platform.dart';
import 'tray_controller.dart';

/// Starts the system tray for this session.
///
/// Only for platforms `systemTraySupported` reports true for. A failure is
/// swallowed: the tray is optional, and it must never keep the app from
/// starting or closing normally.
void launchSystemTray() => unawaited(_launch());

Future<void> _launch() async {
  try {
    final controller = TrayController(
      platform: NativeTrayPlatform(),
      binding: WidgetsBinding.instance,
    );
    await controller.start();
  } catch (_) {
    // No tray on this session; everything else keeps working.
  }
}

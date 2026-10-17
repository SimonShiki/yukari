import 'dart:io';

import 'linux_autostart.dart';
import 'windows_autostart.dart';

/// Registers the app to launch when the user signs in.
abstract interface class Autostart {
  /// Whether the running platform can launch the app at sign-in.
  bool get supported;

  /// Adds or removes the sign-in launch.
  Future<void> setEnabled(bool enabled);
}

/// The [Autostart] for the running platform.
///
/// Android and mobile systems have no supported way for an app to start at
/// boot, so they report unsupported and the settings page hides the option.
Autostart platformAutostart() => switch (Platform.operatingSystem) {
  'linux' => LinuxAutostart(),
  'windows' => WindowsAutostart(),
  _ => const UnsupportedAutostart(),
};

/// An [Autostart] for platforms that cannot launch the app at sign-in.
final class UnsupportedAutostart implements Autostart {
  const UnsupportedAutostart();

  @override
  bool get supported => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

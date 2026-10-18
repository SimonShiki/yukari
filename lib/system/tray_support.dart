import 'dart:io';

/// Whether the running platform can keep the app in a system tray.
///
/// Windows and Linux desktops can; Android and the other targets cannot, so
/// both the setting and the tray itself stay off there.
bool get systemTraySupported => Platform.isLinux || Platform.isWindows;

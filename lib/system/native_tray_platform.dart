import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:local_notifier/local_notifier.dart';
import 'package:nativeapi_flutter/nativeapi_flutter.dart'
    show Window, WindowCloseRequestedEvent, WindowManager;
import 'package:tray_manager/tray_manager.dart';

import '../signals/backend.dart' as active;
import 'tray_menu.dart';
import 'tray_platform.dart';

part 'native_tray_menu.dart';

/// The real [TrayPlatform]: tray_manager draws the StatusNotifierItem (Linux)
/// or notification-area icon (Windows) and takes the menu; the nativeapi core
/// behind it owns the window, so its close can be intercepted; local_notifier
/// shows the one-time notice.
final class NativeTrayPlatform implements TrayPlatform {
  TrayIcon? _icon;
  ListenerId? _iconListener;
  Menu? _menu;
  final Map<String, MenuItem> _items = {};
  final List<(MenuItem, ListenerId)> _itemListeners = [];
  Map<String, TrayMenuItem> _modelById = const {};
  String _structure = '';

  /// The image the tray draws from, kept alive until it is replaced.
  Image? _image;

  Window? _window;
  ListenerId? _windowListener;
  bool Function()? _keepRunning;

  bool _notifierReady = false;

  @override
  Future<bool> initialize() async {
    if (!TrayManager.instance.isSupported()) return false;
    if (!await _hasTrayHost()) return false;
    final icon = TrayIcon.create();
    if (icon == null) return false;
    _icon = icon
      ..setTooltip('Yukari')
      ..setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    // Linux panels keep the icon's clicks and open the menu themselves.
    _iconListener = icon.addListener((event) {
      if (event is TrayIconClickedEvent) showWindow();
    });
    try {
      await localNotifier.setup(appName: 'Yukari');
      _notifierReady = true;
    } catch (_) {
      // A desktop without a notification service still has a tray.
    }
    return true;
  }

  /// Linux draws tray icons only when a StatusNotifier host owns one of the
  /// watcher names; without one, as on GNOME without its AppIndicator
  /// extension, the icon would be invisible and hiding the window into it
  /// would strand the app. `TrayManager.isSupported()` only proves the session
  /// bus exists.
  Future<bool> _hasTrayHost() async {
    if (!Platform.isLinux) return true;
    final client = DBusClient.session();
    try {
      for (final name in const [
        'org.kde.StatusNotifierWatcher',
        'com.canonical.StatusNotifierWatcher',
      ]) {
        final reply = await client
            .callMethod(
              destination: 'org.freedesktop.DBus',
              path: DBusObjectPath('/org/freedesktop/DBus'),
              interface: 'org.freedesktop.DBus',
              name: 'NameHasOwner',
              values: [DBusString(name)],
            )
            .timeout(const Duration(seconds: 2));
        if (reply.returnValues.first.asBoolean()) return true;
      }
      return false;
    } catch (_) {
      // No session bus, or it does not answer: no tray either.
      return false;
    } finally {
      await client.close();
    }
  }

  @override
  Future<void> setIcon(String asset) async {
    final icon = ImageAsset.fromAsset(asset);
    if (icon == null) return;
    _icon?.icon = icon;
    final previous = _image;
    _image = icon;
    previous?.dispose();
  }

  @override
  Future<void> setMenu(TrayMenu menu) async {
    final structure = _structureOf(menu.entries);
    _modelById = {
      for (final entry in menu.entries)
        if (entry is TrayMenuItem) entry.id: entry,
    };
    if (structure != _structure || _menu == null) {
      _buildMenu(menu, structure);
      return;
    }
    _updateItems(menu.entries);
  }

  @override
  Future<void> setVisible(bool visible) async {
    _icon?.setVisible(visible);
  }

  @override
  void interceptClose(bool Function() keepRunning) {
    _keepRunning = keepRunning;
    // The Flutter window may not exist until its first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachWindow());
  }

  void _attachWindow() {
    if (_window != null) return;
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    _windowListener = window.addListener((event) {
      if (event is! WindowCloseRequestedEvent || !event.request.isCancelable) {
        return;
      }
      if (_keepRunning?.call() ?? false) event.request.cancel();
    });
  }

  @override
  void showWindow() {
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    window
      ..show()
      ..focus();
  }

  @override
  void hideWindow() {
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    window.hide();
  }

  @override
  Future<void> notify(String title, String body) async {
    if (!_notifierReady) return;
    await LocalNotification(title: title, body: body).show();
  }

  @override
  Future<void> quit() async {
    _disposeTray();
    try {
      // The in-process backend stops its instances; a service backend leaves
      // them to the service, as closing the window always did.
      await active.backend.peek().dispose();
    } catch (_) {
      // A backend that is already gone must not keep the app from quitting.
    }
    exit(0);
  }
}

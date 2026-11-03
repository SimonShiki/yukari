import 'package:yukari/system/tray_menu.dart';
import 'package:yukari/system/tray_platform.dart';

/// A [TrayPlatform] that records everything the controller asked it to do.
final class FakeTrayPlatform implements TrayPlatform {
  /// What [initialize] reports: whether this session has a tray icon the app
  /// can put on screen.
  bool available = true;

  int initializeCalls = 0;
  int showWindowCalls = 0;
  int hideWindowCalls = 0;
  int quitCalls = 0;
  bool? visible;
  bool Function()? closeInterceptor;

  /// Every menu the controller set, oldest first.
  final List<TrayMenu> menus = [];

  /// Every icon asset the controller drew, oldest first.
  final List<String> icons = [];

  /// Every notification, as (title, body) pairs.
  final List<(String, String)> notices = [];

  /// When set, [notify] throws it instead of showing a notice.
  Object? notifyError;

  TrayMenu? get menu => menus.isEmpty ? null : menus.last;

  /// The row of the last menu with [id], submenus included.
  TrayMenuItem? item(String id) {
    final current = menu;
    if (current == null) return null;
    for (final entry in current.entries) {
      if (entry is TrayMenuItem && entry.id == id) return entry;
    }
    return null;
  }

  /// The close button the controller wired, invoked like the window would.
  bool closeWindow() => closeInterceptor?.call() ?? false;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return available;
  }

  @override
  Future<void> setIcon(String asset) async => icons.add(asset);

  @override
  Future<void> setMenu(TrayMenu menu) async => menus.add(menu);

  @override
  Future<void> setVisible(bool visible) async => this.visible = visible;

  @override
  void interceptClose(bool Function() keepRunning) =>
      closeInterceptor = keepRunning;

  @override
  void showWindow() => showWindowCalls++;

  @override
  void hideWindow() => hideWindowCalls++;

  @override
  Future<void> notify(String title, String body) async {
    if (notifyError case final error?) throw error;
    notices.add((title, body));
  }

  @override
  Future<void> quit() async => quitCalls++;
}

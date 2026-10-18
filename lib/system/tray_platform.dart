import 'tray_menu.dart';

/// The desktop side of the tray: the icon and its menu, the window they
/// restore, and the one-time notice. The app uses [NativeTrayPlatform]; tests
/// use a fake, so no plugin is needed.
abstract interface class TrayPlatform {
  /// Creates the tray icon, and reports whether this session has one the app
  /// can put on screen. False when the desktop shows no tray at all, as on a
  /// Linux session without a StatusNotifier host: the caller must then keep
  /// closing the window exiting instead of hiding it somewhere invisible.
  Future<bool> initialize();

  /// Draws [asset] (a PNG asset name) as the tray icon.
  Future<void> setIcon(String asset);

  /// Shows [menu] in the tray, updating a menu it already shows.
  Future<void> setMenu(TrayMenu menu);

  /// Shows or removes the tray icon.
  Future<void> setVisible(bool visible);

  /// Asks [keepRunning] when the user closes the window. When it answers true
  /// the window is only hidden and the app keeps running; false lets the close
  /// through, which ends the app.
  void interceptClose(bool Function() keepRunning);

  /// Shows and focuses the app window.
  void showWindow();

  /// Hides the app window, keeping the app running.
  void hideWindow();

  /// Shows an OS notification.
  Future<void> notify(String title, String body);

  /// Quits the app, releasing the backend first.
  Future<void> quit();
}

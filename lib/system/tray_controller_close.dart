part of 'tray_controller.dart';

/// What the tray does when the window is closed, and the one-time notice.
extension _TrayClose on TrayController {
  /// Answers a window close: true keeps the app running in the tray.
  bool _closeRequested() {
    if (_disposed || !_trayExists || !settings.behavior.useSystemTray.peek()) {
      return false;
    }
    platform.hideWindow();
    unawaited(_noticeToTray());
    return true;
  }

  /// Shows the "still running" notice, once in the app's lifetime.
  Future<void> _noticeToTray() async {
    if (_noticeShown == true || _noticePending) return;
    _noticePending = true;
    try {
      final prefs = await _preferences();
      if (prefs?.getBool(_noticeShownKey) ?? false) {
        _noticeShown = true;
        return;
      }
      final strings = l10n.value;
      await platform.notify(strings.trayNoticeTitle, strings.trayNoticeBody);
      _noticeShown = true;
      await prefs?.setBool(_noticeShownKey, true);
    } catch (_) {
      // A tray without notifications still works; the flag stays unset so a
      // later close may try again.
    } finally {
      _noticePending = false;
    }
  }

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Shows, draws or removes the tray icon as the setting says.
  Future<void> _applyEnabled(bool enabled) async {
    if (!_trayExists || !enabled) {
      await platform.setVisible(false);
      return;
    }
    await platform.setIcon(trayIconFor(_brightness));
    await platform.setVisible(true);
    _scheduleMenuUpdate(_buildMenu());
  }
}

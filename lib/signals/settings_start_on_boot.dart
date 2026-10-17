part of 'settings.dart';

/// Applies the start-on-boot setting to the OS, one change at a time.
///
/// The last value the user asked for wins: a change requested while an apply is
/// in flight is applied after it, so the OS, the signal and the saved value end
/// up agreeing. A change the OS refuses returns the signal and the saved value
/// to the last value the OS accepted, and is not retried.
final class _StartOnBootApplier {
  _StartOnBootApplier(this._signal, this._autostart);

  final Signal<bool> _signal;
  final Autostart _autostart;

  bool _requested = false;
  bool? _applied;
  bool _draining = false;

  /// Applies [enabled] now, or after the apply in flight.
  void request(SharedPreferences prefs, bool enabled) {
    _requested = enabled;
    if (_draining) return;
    _draining = true;
    unawaited(_drain(prefs));
  }

  /// Applies the loaded value and waits for the OS to take it.
  Future<void> applyLoaded(SharedPreferences prefs, bool enabled) {
    _requested = enabled;
    _draining = true;
    return _drain(prefs);
  }

  Future<void> _drain(SharedPreferences prefs) async {
    try {
      while (_requested != _applied) {
        if (!await _apply(prefs, _requested)) return;
      }
    } finally {
      _draining = false;
    }
  }

  /// Applies [enabled] and saves it. False when the OS refused.
  Future<bool> _apply(SharedPreferences prefs, bool enabled) async {
    try {
      await _autostart.setEnabled(enabled);
    } catch (_) {
      final accepted = _applied ?? false;
      _applied = accepted;
      _requested = accepted;
      _signal.value = accepted;
      await _save(prefs, accepted);
      return false;
    }
    _applied = enabled;
    await _save(prefs, enabled);
    return true;
  }

  Future<void> _save(SharedPreferences prefs, bool enabled) async {
    try {
      await prefs.setBool(_startOnBootKey, enabled);
    } catch (_) {
      // The OS state is what applies; a failed save must not crash the app.
    }
  }
}

import 'package:material_ui/material_ui.dart';

/// Tracks whether a page may refresh: the app is in the foreground and the
/// page's route is the one on top.
///
/// Mix into a page `State` that is also a [WidgetsBindingObserver], call
/// [startForegroundTracking] from `initState` and [stopForegroundTracking]
/// first in `dispose`, then implement [setActive] to start or stop the page's
/// periodic refresh. [didChangeDependencies] re-checks when the route changes.
mixin ForegroundActive<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  bool _foreground = true;

  /// Runs the page's periodic refresh, or stops it.
  void setActive(bool active);

  /// Starts following the app lifecycle.
  void startForegroundTracking() => WidgetsBinding.instance.addObserver(this);

  /// Stops the refresh and stops following the app lifecycle.
  void stopForegroundTracking() {
    WidgetsBinding.instance.removeObserver(this);
    setActive(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncActive();
  }

  void _syncActive() =>
      setActive(_foreground && (ModalRoute.isCurrentOf(context) ?? false));
}

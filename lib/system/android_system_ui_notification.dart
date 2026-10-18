part of 'android_system_ui.dart';

/// The running-network notification: its content, and the permission the
/// system needs to show it.
extension _AndroidSystemUiNotification on AndroidSystemUi {
  void _pushNotification(
    MapEntry<String, Instance>? entry,
    TrafficSample sample,
  ) {
    if (entry == null) {
      if (_notification == null) return;
      _notification = null;
      unawaited(
        _channel.invokeMethod<void>('updateNotification', {'active': false}),
      );
      return;
    }
    _requestNotificationPermission();
    final next = (
      title: entry.value.network.networkName,
      text:
          '${l10n.value.androidNotificationPeers(entry.value.memberCount)} · '
          '${formatTrafficRates(receive: sample.receiveRate, send: sample.sendRate)}',
    );
    if (next == _notification) return;
    _notification = next;
    unawaited(
      _channel.invokeMethod<void>('updateNotification', {
        'active': true,
        'title': next.title,
        'text': next.text,
        'stopLabel': l10n.value.commonStop,
      }),
    );
  }

  /// Asks for POST_NOTIFICATIONS once per process, and only while the app can
  /// show the dialog; a denied permission only means no notification.
  void _requestNotificationPermission() {
    if (_permissionRequested || !_foreground) return;
    _permissionRequested = true;
    unawaited(_channel.invokeMethod<bool>('requestNotificationPermission'));
  }
}

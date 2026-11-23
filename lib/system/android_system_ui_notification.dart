part of 'android_system_ui.dart';

/// The running-network notification: its content, and the permission the
/// system needs to show it.
extension _AndroidSystemUiNotification on AndroidSystemUi {
  void _pushNotification(
    List<MapEntry<String, Instance>> entries,
    TrafficSample sample,
  ) {
    if (entries.isEmpty) {
      if (_notification == null) return;
      _notification = null;
      _channel.invokeMethod<void>('updateNotification', {'active': false}).ignore();
      return;
    }
    _requestNotificationPermission();
    final title = entries.length == 1
        ? entries.single.value.network.networkName
        : l10n.value.androidNotificationNetworks(entries.length);
    final members = entries.fold<int>(
      0,
      (total, entry) => total + entry.value.memberCount,
    );
    final next = (
      title: title,
      text:
          '${l10n.value.androidNotificationPeers(members)} · '
          '${formatTrafficRates(receive: sample.receiveRate, send: sample.sendRate)}',
    );
    if (next == _notification) return;
    _notification = next;
    _channel.invokeMethod<void>('updateNotification', {
      'active': true,
      'title': next.title,
      'text': next.text,
      'stopLabel': l10n.value.commonStop,
    }).ignore();
  }

  /// Asks for POST_NOTIFICATIONS once per process, and only while the app can
  /// show the dialog; a denied permission only means no notification.
  void _requestNotificationPermission() {
    if (_permissionRequested || !_foreground) return;
    _permissionRequested = true;
    _channel.invokeMethod<bool>('requestNotificationPermission').ignore();
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../backend/android_vpn.dart';
import '../backend/backend.dart';
import '../backend/system/service_control.dart';
import '../controllers/home_controller.dart' show TrafficSample, measureTraffic;
import '../models/models.dart';
import '../signals/instances.dart' as running;
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../utils/byte_units.dart';

part 'android_system_ui_actions.dart';
part 'android_system_ui_notification.dart';

/// Mirrors the running network into Android's system UI: the Quick Settings
/// tile and the running-network notification.
///
/// It reads the app's own signals and sends the taps back through the same
/// backend and service control the pages use; it never polls and keeps no
/// state of its own beyond the traffic sample the notification needs.
///
/// **Initialization**: construct it once at app startup, before the app runs,
/// with the app-wide [backend], [backendKind], [backendStatus] signals.
class AndroidSystemUi {
  AndroidSystemUi({
    required this.backend,
    required this.backendKind,
    required this.backendStatus,
    required this.serviceControl,
    Future<bool> Function()? vpnPermissionGranted,
  }) : _vpnPermissionGranted =
           vpnPermissionGranted ?? AndroidVpnService.hasVpnPermission;

  /// Name of the channel the native tile and notification talk on.
  static const channelName = 'top.simonshiki.yukari/system';

  /// The network booted last, which the tile boots again.
  static const _lastBootedKey = 'android.lastBootedNetwork';

  /// How long a pending action stays valid: Android re-delivers a launch
  /// intent when it recreates the activity, and an old toggle must not run.
  static const _pendingActionMaxAge = Duration(minutes: 1);

  /// The tile's label while no network runs.
  static const _idleLabel = 'Yukari';

  final ReadonlySignal<NetworkBackend> backend;
  final ReadonlySignal<BackendKind> backendKind;
  final ReadonlySignal<BackendStatus> backendStatus;
  final ServiceControl serviceControl;

  /// Whether Android already granted the VPN consent, asked without showing a
  /// dialog, as a tile tap in the background must.
  final Future<bool> Function() _vpnPermissionGranted;

  final MethodChannel _channel = const MethodChannel(channelName);
  final List<EffectCleanup> _effects = [];

  SharedPreferences? _prefs;
  String? _lastBooted;
  TrafficSample _traffic = (
    received: 0,
    sent: 0,
    receiveRate: 0,
    sendRate: 0,
    at: null,
  );
  Map<String, Instance>? _sampled;
  ({bool active, String label})? _tile;
  ({String title, String text})? _notification;
  bool _permissionRequested = false;
  bool _started = false;
  bool _disposed = false;

  /// Starts mirroring the signals, then runs the action the app was launched
  /// with, such as a tile tap that had to open the dead app.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler(_onMethodCall);
    _prefs = await SharedPreferences.getInstance();
    _lastBooted = _prefs?.getString(_lastBootedKey);
    await _channel.invokeMethod<void>('ready');
    final pending = await _channel.invokeMethod<Map<Object?, Object?>>(
      'takePendingAction',
    );
    // A process that died while a no-TUN network ran leaves its plain
    // notification behind, and nothing in this process remembers showing it.
    await _channel.invokeMethod<void>('updateNotification', {'active': false});
    _effects.add(effect(_sync));
    unawaited(_refresh());
    if (pending != null) _runPending(pending);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final cleanup in _effects) {
      cleanup();
    }
    _effects.clear();
    _channel.setMethodCallHandler(null);
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method != 'onAction') return null;
    if (call.arguments case {
      'action': final String action,
      'source': final String source,
    }) {
      await _handleAction(action, fromTile: source == 'tile');
    }
    return null;
  }

  /// Runs the action the app was launched with, unless Android re-delivered an
  /// old one when it recreated the activity. A stop is harmless to replay. The
  /// app was just brought forward, so the action may show a dialog.
  void _runPending(Map<Object?, Object?> pending) {
    final action = pending['action'];
    if (action is! String) return;
    if (action == 'toggle' && !_isFresh(pending['at'])) return;
    unawaited(_handleAction(action, fromTile: false));
  }

  bool _isFresh(Object? at) =>
      at is int &&
      DateTime.now().millisecondsSinceEpoch - at <=
          _pendingActionMaxAge.inMilliseconds;

  NetworkBackend get _backend => backend.value;

  BackendKind get _kind => backendKind.value;

  /// Whether the app can show a permission dialog: the app process may be
  /// alive only to serve the tile.
  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Pushes the state of the signals into the tile and the notification.
  void _sync() {
    if (_disposed) return;
    final instances = running.instances.value;
    // Measure only on the pages' own collections, not on a mode or language
    // change: a fresh sample of a nearly zero interval would read as a burst.
    if (!identical(instances, _sampled)) {
      _traffic = measureTraffic(instances, _traffic);
      _sampled = instances;
    }
    final kind = _kind;
    final entry = kind == BackendKind.ffi ? _runningEntry(instances) : null;
    if (entry != null) _rememberBooted(entry.key);
    _pushTile(kind: kind, entry: entry);
    _pushNotification(entry, _traffic);
  }

  /// The first running instance, or null: an in-process backend runs one.
  MapEntry<String, Instance>? _runningEntry(Map<String, Instance> instances) {
    for (final entry in instances.entries) {
      if (entry.value.status == InstanceStatus.running) return entry;
    }
    return null;
  }

  void _pushTile({
    required BackendKind kind,
    required MapEntry<String, Instance>? entry,
  }) {
    final active = switch (kind) {
      BackendKind.ffi => entry != null,
      BackendKind.service => backendStatus.value == BackendStatus.ready,
    };
    final label = kind == BackendKind.ffi && entry != null
        ? entry.value.network.networkName
        : _idleLabel;
    final next = (active: active, label: label);
    if (next == _tile) return;
    _tile = next;
    unawaited(
      _channel.invokeMethod<void>('setTileState', {
        'active': next.active,
        'label': next.label,
      }),
    );
  }
}

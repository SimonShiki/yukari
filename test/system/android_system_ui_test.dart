import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/system/android_system_ui.dart';

import '../fake_backend.dart';
import '../fake_service_control.dart';
import '../networks_fixture.dart';
import 'instance_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late _TestBackend backend;
  late Signal<NetworkBackend> backends;
  late Signal<BackendKind> kinds;
  late Signal<BackendStatus> statuses;
  late FakeServiceControl control;
  String? pendingAction;
  int? pendingActionAt;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await seedNetworks();
    calls = [];
    pendingAction = null;
    pendingActionAt = null;
    backend = _TestBackend();
    backends = signal<NetworkBackend>(backend);
    kinds = signal(BackendKind.ffi);
    statuses = signal(BackendStatus.ready);
    control = FakeServiceControl();
    messenger.setMockMethodCallHandler(
      const MethodChannel(AndroidSystemUi.channelName),
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'takePendingAction' => pendingAction == null
              ? null
              : {
                  'action': pendingAction,
                  'source': 'intent',
                  'at':
                      pendingActionAt ??
                      DateTime.now().millisecondsSinceEpoch,
                },
          'requestNotificationPermission' => true,
          _ => null,
        };
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel(AndroidSystemUi.channelName),
      null,
    );
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Future<AndroidSystemUi> startUi({
    Future<bool> Function()? vpnPermissionGranted,
  }) async {
    final ui = AndroidSystemUi(
      backend: backends,
      backendKind: kinds,
      backendStatus: statuses,
      serviceControl: control,
      vpnPermissionGranted: vpnPermissionGranted,
    );
    addTearDown(ui.dispose);
    await ui.start();
    await pumpEventQueue();
    return ui;
  }

  /// Delivers what the native tile or the app's launch intent sends back.
  Future<void> sendAction(String action, {String source = 'tile'}) async {
    await messenger.handlePlatformMessage(
      AndroidSystemUi.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAction', {'action': action, 'source': source}),
      ),
      null,
    );
    await pumpEventQueue();
  }

  Iterable<MethodCall> methodCalls(String method) =>
      calls.where((call) => call.method == method);

  MethodCall lastCall(String method) => calls.lastWhere(
    (call) => call.method == method,
  );

  Map<Object?, Object?> lastArguments(String method) =>
      lastCall(method).arguments as Map<Object?, Object?>;

  test('boots the last booted network, else the first saved one', () {
    final networks = saved.networks.value;

    expect(bootNetworkId(networks, 'n2'), 'n2');
    expect(bootNetworkId(networks, 'deleted'), 'n1');
    expect(bootNetworkId(networks, null), 'n1');
    expect(bootNetworkId(const {}, 'n1'), isNull);
  });

  test('shows a running network on the tile and in the notification', () async {
    backend = _TestBackend(peerCount: 2);
    backends.value = backend;
    await startUi();

    await sendAction('toggle');

    expect(backend.started.keys, ['n1']);
    expect(lastArguments('setTileState'), {
      'active': true,
      'label': 'alpha',
    });
    final notification = lastArguments('updateNotification');
    expect(notification['title'], 'alpha');
    expect(notification['text'], '2 peers · ↓ 0 B/s  ↑ 0 B/s');
    expect(notification['stopLabel'], 'Stop');
    expect(
      calls.where((call) => call.method == 'requestNotificationPermission'),
      hasLength(1),
    );
  });

  test('the notification Stop action stops the network and clears both', () async {
    backend = _TestBackend();
    backends.value = backend;
    await startUi();
    await sendAction('toggle');

    await sendAction('stop');

    expect(backend.stopped, contains('alpha'));
    expect(lastArguments('setTileState'), {
      'active': false,
      'label': 'Yukari',
    });
    expect(lastArguments('updateNotification'), {'active': false});
  });

  test('a second tile tap stops the network', () async {
    backend = _TestBackend();
    backends.value = backend;
    await startUi();
    await sendAction('toggle');

    await sendAction('toggle');

    expect(backend.stopped, contains('alpha'));
    expect(lastArguments('setTileState'), {
      'active': false,
      'label': 'Yukari',
    });
  });

  test('remembers the network it booted for the next tile tap', () async {
    await startUi();
    await sendAction('toggle');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('android.lastBootedNetwork'), 'n1');
  });

  test('a tile tap that opens a dead app boots the saved network', () async {
    pendingAction = 'toggle';
    await startUi();
    await pumpEventQueue();

    expect(backend.started.keys, ['n1']);
    expect(lastArguments('setTileState'), {
      'active': true,
      'label': 'alpha',
    });
  });

  test('a cold app boots the network booted last', () async {
    SharedPreferences.setMockInitialValues({
      'android.lastBootedNetwork': 'n2',
    });
    backend = _TestBackend();
    backends.value = backend;
    pendingAction = 'toggle';
    await startUi();
    await pumpEventQueue();

    expect(backend.started.keys, ['n2']);
    expect(lastArguments('setTileState')['label'], 'beta');
  });

  test('a stop action sent to a cold app stops the network it finds', () async {
    backend = _TestBackend();
    backends.value = backend;
    // The instance survives in the process, but no Dart store knows it yet.
    backend.started['n1'] = saved.networks.value['n1']!;
    pendingAction = 'stop';
    await startUi();
    await pumpEventQueue();

    expect(backend.stopped, contains('alpha'));
  });

  test('ignores a pending action Android re-delivers long after', () async {
    backend = _TestBackend();
    backends.value = backend;
    pendingAction = 'toggle';
    pendingActionAt = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch;
    await startUi();
    await pumpEventQueue();

    expect(backend.started, isEmpty);
  });

  test('a fresh process clears the notification the last one left', () async {
    await startUi();

    final notifications = methodCalls('updateNotification').toList();
    expect(notifications, hasLength(1));
    expect(notifications.single.arguments, {'active': false});
  });

  test('a fresh process clears then mirrors a network that survived it', () async {
    backend.started['n1'] = saved.networks.value['n1']!;
    await startUi();
    await pumpEventQueue();

    final notifications = methodCalls('updateNotification').toList();
    expect(notifications.first.arguments, {'active': false});
    expect(notifications.last.arguments?['active'], isTrue);
  });

  test('a background tap without the VPN consent opens the app to ask', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    var asked = false;
    await startUi(
      vpnPermissionGranted: () async {
        asked = true;
        return false;
      },
    );

    await sendAction('toggle');

    expect(asked, isTrue);
    expect(backend.started, isEmpty);
    expect(methodCalls('openApp'), hasLength(1));
    expect(methodCalls('requestNotificationPermission'), isEmpty);
  });

  test('a tile tap the app opens may then ask for the VPN consent', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await startUi(vpnPermissionGranted: () async => false);
    await sendAction('toggle');
    expect(backend.started, isEmpty);
    expect(methodCalls('openApp'), hasLength(1));

    // The launched intent delivers the same toggle, and the app can now show
    // the consent dialog.
    await sendAction('toggle', source: 'intent');

    expect(backend.started.keys, ['n1']);
  });

  test('a refused background start opens the app to retry', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await startUi(vpnPermissionGranted: () async => true);
    backend.startError = StateError('Foreground service start refused');

    await sendAction('toggle');

    expect(backend.started, isEmpty);
    expect(methodCalls('openApp'), hasLength(1));
  });

  test('an intent-delivered failed start does not loop back to the app', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await startUi(vpnPermissionGranted: () async => true);
    backend.startError = StateError('Foreground service start refused');

    // The app was already brought forward for this action; a start that still
    // fails there must not open it again.
    await sendAction('toggle', source: 'intent');

    expect(backend.started, isEmpty);
    expect(methodCalls('openApp'), isEmpty);
  });

  test('a background tap starts silently once the VPN consent is granted', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await startUi(vpnPermissionGranted: () async => true);

    await sendAction('toggle');

    expect(backend.started.keys, ['n1']);
    expect(methodCalls('openApp'), isEmpty);
  });

  test('the tile turns the background service off', () async {
    kinds.value = BackendKind.service;
    control.current = ServiceState.running;
    await startUi();
    expect(lastArguments('setTileState'), {
      'active': true,
      'label': 'Yukari',
    });

    await sendAction('toggle');

    expect(control.calls, ['stop']);
    // The backend's view of the service is what the tile follows.
    statuses.value = BackendStatus.unavailable;
    await pumpEventQueue();
    expect(lastArguments('setTileState'), {
      'active': false,
      'label': 'Yukari',
    });
    // Only the startup clear; a service-mode run shows no notification.
    final notifications = methodCalls('updateNotification').toList();
    expect(notifications, hasLength(1));
    expect(notifications.single.arguments, {'active': false});
  });

  test('the tile turns the background service on', () async {
    kinds.value = BackendKind.service;
    control.current = ServiceState.stopped;
    statuses.value = BackendStatus.unavailable;
    await startUi();

    await sendAction('toggle');

    expect(control.calls, ['start']);
    statuses.value = BackendStatus.ready;
    await pumpEventQueue();
    expect(lastArguments('setTileState')['active'], isTrue);
  });

  test('the tile leaves a service that needs root alone', () async {
    kinds.value = BackendKind.service;
    control.current = ServiceState.rootRequired;
    await startUi();

    await sendAction('toggle');

    expect(control.calls, isEmpty);
  });
}

/// A backend that reports the networks it started, each with [peerCount]
/// peers, like EasyTier as they connect.
class _TestBackend extends FakeBackend {
  _TestBackend({this.peerCount = 0});

  final int peerCount;

  @override
  Future<Map<String, String>> collectInfos() async => {
    for (final network in started.values)
      network.networkName: jsonEncode(
        instanceInfo(
          peers: [for (var i = 0; i < peerCount; i++) instancePeer()],
        ),
      ),
  };
}

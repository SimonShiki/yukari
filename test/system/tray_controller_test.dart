import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/instance_logs.dart';
import 'package:yukari/signals/instances.dart' as running;
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/tray_controller.dart';
import 'package:yukari/system/tray_menu.dart';

import '../async_support.dart';
import '../fake_autostart.dart';
import '../fake_backend.dart';
import '../fake_tray_platform.dart';
import '../networks_fixture.dart';
import 'instance_info.dart';
import 'service_like_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: FakeAutostart());
    await seedNetworks();
  });

  TrayController controller(
    FakeTrayPlatform platform, {
    NetworkBackend? backend,
    Duration refreshInterval = const Duration(seconds: 2),
  }) {
    final backendSignal = signal<NetworkBackend>(backend ?? FakeBackend());
    final created = TrayController(
      platform: platform,
      backend: backendSignal,
      refreshInterval: refreshInterval,
    );
    addTearDown(() {
      created.dispose();
      backendSignal.dispose();
    });
    return created;
  }

  /// The main window's networks list controller, reading the same stores.
  NetworkPageController pageController(NetworkBackend backend) {
    final created = NetworkPageController(
      backend: backend,
      navigate: (route, id) {},
      showMessage: (message) {},
      confirmDelete: (network) async => false,
      showTunPermissionWarning: (network) async {},
    );
    addTearDown(created.dispose);
    // The main window is visible: its controller keeps collecting while it is.
    created.setActive(true);
    return created;
  }

  bool cardRunning(NetworkPageController page, String id) =>
      page.cards.value.firstWhere((card) => card.id == id).running;

  /// Waits for [condition], giving the service-like backend's multi-millisecond
  /// calls real time to settle; [waitFor]'s zero-delay turns do not wait long
  /// enough for them.
  Future<void> eventually(bool Function() condition) async {
    for (var turn = 0; turn < 200; turn++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  test('starts the tray with the theme icon and the localized menu', () async {
    final platform = FakeTrayPlatform();
    await controller(platform).start();
    await pumpEventQueue();

    expect(platform.initializeCalls, 1);
    expect(
      settings.behavior.trayAvailable.value,
      isTrue,
      reason: 'the settings row may offer to hide the window in this tray',
    );
    expect(platform.visible, isTrue);
    expect(platform.closeInterceptor, isNotNull);
    expect(platform.icons, ['assets/generated/yukari-tray-light.png']);
    expect(_labels(platform.menu!), [
      'Open',
      'Networks',
      'alpha',
      'beta',
      'Exit',
    ], reason: 'networks are a flat section, not a submenu');
    expect(
      platform.item('networks')!.enabled,
      isFalse,
      reason: 'the section label is not clickable',
    );
    expect(platform.item('network:n1'), isNotNull);
  });

  test('keeps closing the app when the session has no tray icon', () async {
    final platform = FakeTrayPlatform()..available = false;
    final tray = controller(platform);
    await tray.start();
    await pumpEventQueue();

    expect(platform.initializeCalls, 1);
    expect(settings.behavior.trayAvailable.value, isFalse);
    expect(
      platform.closeInterceptor,
      isNull,
      reason: 'the close button must not hide the app somewhere invisible',
    );
    expect(platform.closeWindow(), isFalse);
    expect(platform.hideWindowCalls, 0);
    expect(
      platform.notices,
      isEmpty,
      reason: 'no notice about a tray that is not there',
    );
    expect(platform.visible, isNull);
    expect(platform.icons, isEmpty);
  });

  test('draws the dark-panel icon when the platform turns dark', () async {
    final platform = FakeTrayPlatform();
    final tray = controller(platform);
    await tray.start();
    await pumpEventQueue();
    platform.icons.clear();

    tray.setBrightness(Brightness.dark);
    expect(platform.icons, ['assets/generated/yukari-tray-dark.png']);

    tray.setBrightness(Brightness.dark);
    expect(
      platform.icons,
      hasLength(1),
      reason: 'the same theme is not redrawn',
    );

    tray.setBrightness(Brightness.light);
    expect(platform.icons.last, 'assets/generated/yukari-tray-light.png');
  });

  test('labels a running network with peers, its own IP and traffic', () async {
    var received = 0;
    final backend = FakeBackend(
      collected: () => {
        'alpha': instanceInfo(
          peers: [
            instancePeer(rx: received, tx: 0),
            instancePeer(rx: received, tx: 0),
          ],
        ),
      },
    );
    final platform = FakeTrayPlatform();
    final tray = controller(platform, backend: backend);
    await tray.start();
    await pumpEventQueue();

    expect(platform.item('network:n1')!.checked, isTrue);
    expect(platform.item('network:n2')!.checked, isFalse);
    expect(
      platform.item('network:n1')!.label,
      'alpha · 2 peers',
      reason: 'the first sample has no rate yet',
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    received = 2048;
    await running.refreshInstances(backend);
    await pumpEventQueue();

    final label = platform.item('network:n1')!.label;
    expect(label, contains('2 peers'), reason: 'the count is kept in place');
    expect(
      platform.item('network:n2')!.label,
      'beta',
      reason: 'a stopped network has no details',
    );
  });

  test('shows a disabled row when no network is saved', () async {
    await seedWith({});
    final platform = FakeTrayPlatform();
    await controller(platform).start();
    await pumpEventQueue();

    expect(_labels(platform.menu!), [
      'Open',
      'Networks',
      'No saved networks',
      'Exit',
    ]);
    expect(platform.item('no-networks')!.enabled, isFalse);
  });

  test('opens the window instead of starting without TUN access', () async {
    final backend = FakeBackend()..access = TunAccess.elevationRequired;
    final platform = FakeTrayPlatform();
    final tray = controller(platform, backend: backend);
    await tray.start();
    await pumpEventQueue();

    platform.item('network:n1')!.onSelected!();
    await waitFor(() => platform.showWindowCalls == 1);

    expect(
      backend.started,
      isEmpty,
      reason: 'access can only be granted in the window',
    );
    expect(platform.item('network:n1')!.checked, isFalse);
  });

  test("a tray start clears the previous run's event log", () async {
    final backend = FakeBackend();
    final platform = FakeTrayPlatform();
    final tray = controller(platform, backend: backend);
    await tray.start();
    await pumpEventQueue();
    recordInstanceEvents('n1', ['an event from the previous run']);
    expect(instanceLogs('n1').value, isNotEmpty);

    platform.item('network:n1')!.onSelected!();
    await waitFor(() => backend.started.containsKey('n1'));

    expect(
      instanceLogs('n1').value,
      isEmpty,
      reason: 'a new run starts with a clean log, as from the page',
    );
  });

  test(
    'mirrors the page list in service mode, before and after actions',
    () async {
      final backend = ServiceLikeBackend();
      final platform = FakeTrayPlatform();
      final tray = controller(platform, backend: backend);
      final page = pageController(backend);
      await tray.start();
      await pumpEventQueue();

      expect(platform.item('network:n1')!.checked, cardRunning(page, 'n1'));
      expect(platform.item('network:n2')!.checked, cardRunning(page, 'n2'));

      // The tray's action lands in the shared store, so the page's cards agree.
      platform.item('network:n1')!.onSelected!();
      await eventually(() => running.instances.value.containsKey('n1'));
      await pumpEventQueue();
      expect(backend.starts, 1);
      expect(platform.item('network:n1')!.checked, isTrue);
      expect(cardRunning(page, 'n1'), isTrue);
      expect(platform.item('network:n2')!.checked, cardRunning(page, 'n2'));

      // A page action is visible to the tray in the same way.
      await page.toggle('n2', true);
      await eventually(() => running.instances.value.containsKey('n2'));
      await pumpEventQueue();
      expect(platform.item('network:n2')!.checked, isTrue);
      expect(cardRunning(page, 'n2'), isTrue);

      // And stopping works from either side.
      await page.toggle('n1', false);
      await eventually(() => !running.instances.value.containsKey('n1'));
      await pumpEventQueue();
      expect(platform.item('network:n1')!.checked, isFalse);
      expect(cardRunning(page, 'n1'), isFalse);

      platform.item('network:n2')!.onSelected!();
      await eventually(() => !running.instances.value.containsKey('n2'));
      await pumpEventQueue();
      expect(platform.item('network:n2')!.checked, isFalse);
      expect(cardRunning(page, 'n2'), isFalse);
    },
  );

  test('a failed collection does not latch the tray actions', () async {
    final backend = ServiceLikeBackend();
    final platform = FakeTrayPlatform();
    final tray = controller(platform, backend: backend);
    await tray.start();
    await pumpEventQueue();

    // The start lands, but the collection that should report it fails. The old
    // tray-owned page controller latched that error and swallowed every later
    // click, so the menu never caught up.
    backend.collectFailures = 1;
    platform.item('network:n1')!.onSelected!();
    await eventually(() => backend.starts == 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(platform.item('network:n1')!.checked, isFalse);

    // The next click sees the store still empty and retries the start; the
    // backend refuses the duplicate, and the successful collection then shows
    // the running network.
    platform.item('network:n1')!.onSelected!();
    await eventually(() => platform.item('network:n1')!.checked == true);
    expect(backend.starts, 2);
  });

  test('opens the window from the menu and quits from it', () async {
    final platform = FakeTrayPlatform();
    await controller(platform).start();
    await pumpEventQueue();

    platform.item('open')!.onSelected!();
    expect(platform.showWindowCalls, 1);

    platform.item('exit')!.onSelected!();
    await waitFor(() => platform.quitCalls == 1);
  });

  test('hides the window and notifies once when it is closed', () async {
    final platform = FakeTrayPlatform();
    await controller(platform).start();
    await pumpEventQueue();

    expect(platform.closeWindow(), isTrue);
    await waitFor(() => platform.notices.length == 1);
    expect(platform.hideWindowCalls, 1);
    expect(platform.notices.single.$1, 'Yukari keeps running');
    expect(platform.notices.single.$2, contains('system tray'));
    expect(
      (await SharedPreferences.getInstance()).getBool('tray.noticeShown'),
      isTrue,
      reason: 'the notice is remembered across launches',
    );

    expect(platform.closeWindow(), isTrue);
    await pumpEventQueue();
    expect(platform.hideWindowCalls, 2);
    expect(platform.notices, hasLength(1), reason: 'it is never repeated');
  });

  test(
    'does not remember the notice when the platform cannot show it',
    () async {
      final platform = FakeTrayPlatform()
        ..notifyError = StateError('no daemon');
      await controller(platform).start();
      await pumpEventQueue();

      expect(platform.closeWindow(), isTrue);
      await waitFor(() => platform.hideWindowCalls == 1);
      await pumpEventQueue();
      expect(platform.notices, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool('tray.noticeShown'),
        isNull,
        reason: 'a failed notice is tried again on a later close',
      );
    },
  );

  test('closes the app when the setting is off', () async {
    final platform = FakeTrayPlatform();
    await controller(platform).start();
    await pumpEventQueue();
    expect(platform.visible, isTrue);

    settings.behavior.setUseSystemTray(false);
    await pumpEventQueue();

    expect(platform.visible, isFalse);
    expect(platform.closeWindow(), isFalse);
    expect(platform.hideWindowCalls, 0);
    expect(platform.notices, isEmpty);
  });

  test('removes and restores the tray when the setting changes', () async {
    final platform = FakeTrayPlatform();
    final tray = controller(platform);
    await tray.start();
    await pumpEventQueue();

    settings.behavior.setUseSystemTray(false);
    await pumpEventQueue();
    expect(platform.visible, isFalse);

    settings.behavior.setUseSystemTray(true);
    await pumpEventQueue();
    expect(platform.visible, isTrue);
    expect(platform.icons, hasLength(2), reason: 'the icon is drawn again');
    tray.setBrightness(Brightness.dark);
    expect(platform.icons.last, 'assets/generated/yukari-tray-dark.png');
  });

  test('disables the network rows while the backend is unavailable', () async {
    final backend = _StatusBackend();
    final platform = FakeTrayPlatform();
    await controller(platform, backend: backend).start();
    await pumpEventQueue();
    expect(platform.item('network:n1')!.enabled, isTrue);

    backend.setStatus(BackendStatus.unavailable);
    await pumpEventQueue();
    expect(platform.item('network:n1')!.enabled, isFalse);

    backend.setStatus(BackendStatus.ready);
    await pumpEventQueue();
    expect(platform.item('network:n1')!.enabled, isTrue);
  });

  test('refreshes traffic only while an instance runs', () async {
    final backend = CountingBackend();
    final platform = FakeTrayPlatform();
    final tray = controller(
      platform,
      backend: backend,
      refreshInterval: const Duration(milliseconds: 25),
    );
    await tray.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      backend.collects,
      1,
      reason: 'nothing runs, so there is nothing to measure',
    );

    backend.started['n1'] = saved.networks.value['n1']!;
    await running.refreshInstances(backend);
    final before = backend.collects;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(backend.collects, greaterThan(before));
  });
}

/// The labels of the menu's rows, in order, without separators.
List<String> _labels(TrayMenu menu) => [
  for (final entry in menu.entries)
    if (entry is TrayMenuItem) entry.label,
];

/// A backend whose status the test drives.
final class _StatusBackend extends FakeBackend {
  final Signal<BackendStatus> _status = signal(BackendStatus.ready);

  @override
  ReadonlySignal<BackendStatus> get status => _status;

  void setStatus(BackendStatus value) => _status.value = value;
}

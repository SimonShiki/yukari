import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari/backend/service_backend.dart';
import 'package:yukari/backend/system/service_control.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/backend.dart' as backend_signals;
import 'package:yukari/signals/settings.dart';

import '../fake_backend.dart';
import '../fake_service_control.dart';
import '../networks_fixture.dart';

void main() {
  // Switching modes persists the choice.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads and writes the interface language through the settings', () {
    final controller = _build(control: FakeServiceControl());
    addTearDown(controller.dispose);

    controller.selectLanguage(const Locale('zh'));

    expect(controller.language.value, const Locale('zh'));
    expect(settings.interface.locale.value, const Locale('zh'));

    controller.selectLanguage(null);
    expect(controller.language.value, isNull);
  });

  test('reads and writes the page transitions through the settings', () {
    final controller = _build(control: FakeServiceControl());
    addTearDown(controller.dispose);
    addTearDown(() => settings.interface.setPageTransitions(true));

    controller.setPageTransitions(false);

    expect(controller.pageTransitions.value, isFalse);
    expect(settings.interface.pageTransitions.value, isFalse);

    settings.interface.setPageTransitions(true);
    expect(controller.pageTransitions.value, isTrue);
  });

  test(
    'disposing during the service check writes no disposed signal',
    () async {
      final gate = Completer<void>();
      final controller = _build(control: FakeServiceControl(stateGate: gate));

      final checking = controller.refresh();
      expect(controller.stateKnown.value, isFalse);
      controller.dispose();
      gate.complete();

      await expectLater(checking, completes);
      expect(controller.stateKnown.peek(), isFalse);
      expect(controller.serviceState.peek(), ServiceState.unsupported);
    },
  );

  test('disposing during an install writes no disposed signal', () async {
    final gate = Completer<void>();
    final controller = _build(control: FakeServiceControl(actionGate: gate));

    final installing = controller.install();
    controller.dispose();
    gate.complete();

    await expectLater(installing, completes);
    expect(
      controller.installProgress.peek(),
      0.25,
      reason: 'the late progress report is dropped',
    );
    expect(controller.installing.peek(), isTrue);
    expect(controller.busy.peek(), isTrue);
  });

  test('disposing during a service action writes no disposed signal', () async {
    final gate = Completer<void>();
    final controller = _build(control: FakeServiceControl(actionGate: gate));

    final starting = controller.start();
    expect(controller.busy.value, isTrue);
    controller.dispose();
    gate.complete();

    await expectLater(starting, completes);
    expect(controller.busy.peek(), isTrue, reason: 'the finally is guarded');
  });

  test('a service action that fails after dispose is not reported', () async {
    final gate = Completer<void>();
    final messages = <String>[];
    final controller = _build(
      control: FakeServiceControl(actionGate: gate, fail: true),
      messages: messages,
    );

    final stopping = controller.stop();
    controller.dispose();
    gate.complete();

    await expectLater(stopping, completes);
    expect(messages, isEmpty);
    expect(controller.busy.peek(), isTrue);
  });

  test('disposing while switching writes no disposed signal', () async {
    await seedNetworks();
    final backend = FakeBackend()
      ..started['alpha'] = (Network()..networkName = 'alpha');
    final asked = Completer<void>();
    final confirm = Completer<bool>();
    final messages = <String>[];
    final controller = _build(
      control: FakeServiceControl(),
      backend: backend,
      messages: messages,
      stop: (_, _) {
        asked.complete();
        return confirm.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    final switching = controller.select(BackendKind.service);
    await asked.future;
    controller.dispose();
    confirm.complete(false);

    await expectLater(switching, completes);
    expect(controller.busy.peek(), isTrue, reason: 'the finally is guarded');
    expect(messages, isEmpty);
  });

  test(
    'disposing during the version probe writes no disposed signal',
    () async {
      final entered = Completer<void>();
      final gate = Completer<void>();
      final controller = _build(
        control: FakeServiceControl(),
        probe: () async {
          entered.complete();
          await gate.future;
          return 7;
        },
      );

      // The service answers first, so the refresh is parked in the version
      // probe, not in the service check.
      final refreshing = controller.refresh();
      await entered.future;
      expect(controller.serviceState.value, ServiceState.running);
      expect(
        controller.stateKnown.value,
        isTrue,
        reason: 'the page shows the state while the version is still coming',
      );
      controller.dispose();
      gate.complete();

      await expectLater(refreshing, completes);
      expect(
        controller.runningVersion.peek(),
        isNull,
        reason: 'the probe result is not written after dispose',
      );
      expect(controller.stateKnown.peek(), isTrue, reason: 'it landed first');
    },
  );

  test('a probe that outlives the version signal is not reported', () async {
    final entered = Completer<void>();
    final gate = Completer<void>();
    final messages = <String>[];
    final controller = _build(
      control: FakeServiceControl(),
      messages: messages,
      probe: () async {
        entered.complete();
        await gate.future;
        return 7;
      },
    );

    final refreshing = controller.refresh();
    await entered.future;
    // The signal the late probe result targets is gone, though the controller
    // itself still is. The write must be skipped, not thrown and swallowed as
    // a service failure.
    controller.runningVersion.dispose();
    gate.complete();

    await expectLater(refreshing, completes);
    expect(controller.runningVersion.peek(), isNull);
    expect(messages, isEmpty);
  });

  test('the shared status signals outlive the controller', () async {
    final controller = _build(control: FakeServiceControl());
    await controller.refresh();

    controller.dispose();

    expect(backend_signals.backendKind.disposed, isFalse);
    expect(backend_signals.backendStatus.disposed, isFalse);
    expect(backend_signals.backendKind.value, BackendKind.ffi);
    expect(backend_signals.backendStatus.value, isNotNull);
  });

  test('refresh asks the backend for one more check', () async {
    final backend = _UnreachableBackend();
    final controller = _build(control: FakeServiceControl(), backend: backend);
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(backend.retries, 1);
  });

  test('an unreachable service does not block switching back', () async {
    final backend = _UnreachableBackend();
    final global = backend_signals.backend as Signal<NetworkBackend>;
    final previous = global.value;
    global.value = backend;
    final messages = <String>[];
    var asked = 0;
    final controller = _build(
      control: FakeServiceControl(),
      backend: backend,
      messages: messages,
      stop: (_, _) async {
        asked++;
        return true;
      },
    );
    addTearDown(() {
      controller.dispose();
      global.value = previous;
    });

    await controller.select(BackendKind.ffi);

    expect(global.value.kind, BackendKind.ffi, reason: 'the switch happened');
    expect(messages, isEmpty, reason: 'the switch is not a failure');
    expect(asked, 0, reason: 'it cannot say what it runs');
  });
}

/// A service backend that cannot be reached, and counts its checks.
class _UnreachableBackend extends FakeBackend {
  @override
  BackendKind get kind => BackendKind.service;

  final _status = signal(BackendStatus.unavailable);

  @override
  ReadonlySignal<BackendStatus> get status => _status;

  /// How often [retry] was called.
  int retries = 0;

  @override
  Future<void> retry() async {
    retries++;
  }

  @override
  Future<Map<String, String>> collectInfos() async {
    throw const ServiceUnavailableException('gone');
  }
}

BackendSettingsController _build({
  required ServiceControl control,
  NetworkBackend? backend,
  Future<bool> Function(BackendKind kind, int count)? stop,
  Future<int?> Function()? probe,
  List<String>? messages,
}) => BackendSettingsController(
  showMessage: (messages ?? []).add,
  confirmStopNetworks: stop ?? (_, _) async => true,
  control: control,
  probeVersion: probe ?? () async => 1,
  backend: backend == null ? null : signal<NetworkBackend>(backend),
);

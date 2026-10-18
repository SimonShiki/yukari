import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/backend/ffi_backend.dart';
import 'package:yukari_core/backend/service_version.dart';
import 'package:yukari/backend/system/service_control.dart';
import 'package:yukari_core/backend/system/system_service.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/settings/settings_page.dart';
import 'package:yukari/pages/settings/widgets/switch_backend_dialog.dart';
import 'package:yukari/signals/backend.dart' as backend_signals;
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/autostart.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';
import 'package:yukari/widgets/form_section/form_segments.dart';
import 'package:yukari/widgets/select_item/select_item.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

/// A service manager that reports [current].
class _FakeSystemService extends SystemService {
  _FakeSystemService(this.current);

  ServiceState current;

  @override
  Future<ServiceState> state() async => current;

  @override
  Future<void> install(String executable, List<String> arguments) async {}

  @override
  Future<void> uninstall() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// A service manager whose [state] answer the test releases.
class _PendingSystemService extends SystemService {
  final _answer = Completer<ServiceState>();

  void complete(ServiceState state) => _answer.complete(state);

  @override
  Future<ServiceState> state() => _answer.future;

  @override
  Future<void> install(String executable, List<String> arguments) async {}

  @override
  Future<void> uninstall() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// A [FakeBackend] in service mode, whose status the test can set.
class _ServiceBackend extends FakeBackend {
  final _status = signal(BackendStatus.ready);

  @override
  Signal<BackendStatus> get status => _status;

  @override
  BackendKind get kind => BackendKind.service;
}

/// A [FakeBackend] whose instances refuse to stop.
class _StubbornBackend extends FakeBackend {
  @override
  Future<void> stop(List<String> names) =>
      Future<void>.error(StateError('the networks are stuck'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> messages;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => settings.interface.setLocale(null));

  Future<BackendSettingsController> pump(
    WidgetTester tester,
    ServiceState state, {
    int version = serviceVersion,
    NetworkBackend? backend,
  }) async {
    messages = [];
    final controller = BackendSettingsController(
      showMessage: messages.add,
      confirmStopNetworks: (_, _) async => true,
      probeVersion: () async => version,
      backend: backend == null ? null : signal<NetworkBackend>(backend),
      control: SystemServiceControl(
        dataDir: '/data',
        system: _FakeSystemService(state),
        // Any existing file stands in for the bundled service executable.
        executable: Platform.resolvedExecutable,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: SettingsPage(controller: controller),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('offers to install a missing service', (tester) async {
    await pump(tester, ServiceState.notInstalled);
    expect(find.text('Not installed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Install'), findsOneWidget);
    expect(find.text('Uninstall'), findsNothing);

    await tester.tap(find.text('Service'));
    await tester.pump();
    expect(messages, ['Install the background service first.']);
  });

  testWidgets('manages a running service', (tester) async {
    final controller = await pump(tester, ServiceState.running);
    expect(find.text('Running'), findsOneWidget);
    expect(find.textContaining('Version $serviceVersion'), findsOneWidget);
    expect(find.text('Reinstall'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Uninstall'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Install'), findsNothing);

    // While an action runs, the row shows a spinner and the rest is disabled.
    controller.busy.value = true;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final uninstall = find.widgetWithText(TextButton, 'Uninstall');
    expect(tester.widget<TextButton>(uninstall).onPressed, isNull);
  });

  testWidgets('offers to update an older running service', (tester) async {
    await pump(tester, ServiceState.running, version: serviceVersion - 1);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
    expect(find.text('Reinstall'), findsNothing);
  });

  testWidgets('shows how far an install has come', (tester) async {
    final controller = await pump(tester, ServiceState.notInstalled);
    controller.installing.value = true;
    controller.installProgress.value = 0.42;
    await tester.pump();
    expect(find.text('Downloading · 42%'), findsOneWidget);
    expect(find.byType(M3ELinearWavyProgressIndicator), findsOneWidget);
    expect(find.text('Install'), findsNothing);

    controller.installProgress.value = null;
    await tester.pump();
    expect(find.text('Installing'), findsOneWidget);
  });

  testWidgets('asks for root before offering the service', (tester) async {
    await pump(tester, ServiceState.rootRequired);
    expect(find.text('Root required'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
    final service = find.widgetWithText(M3EListItem, 'Service');
    expect(tester.widget<M3EListItem>(service).enabled, isFalse);

    await tester.tap(find.text('Service'));
    await tester.pump();
    expect(messages, ['Grant Yukari root access first.']);
  });

  testWidgets('wraps long mode descriptions', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, ServiceState.running);
    final detail = find.textContaining('Run networks as system service');
    final paragraph = tester.renderObject<RenderParagraph>(detail);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(paragraph.preferredLineHeight));
  });

  testWidgets('explains a platform without a service', (tester) async {
    await pump(tester, ServiceState.unsupported);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
  });

  testWidgets('holds the service section still until the state lands', (
    tester,
  ) async {
    messages = [];
    final service = _PendingSystemService();
    final controller = BackendSettingsController(
      showMessage: messages.add,
      confirmStopNetworks: (_, _) async => true,
      probeVersion: () async => serviceVersion,
      control: SystemServiceControl(
        dataDir: '/data',
        system: service,
        executable: Platform.resolvedExecutable,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: SettingsPage(controller: controller),
      ),
    );
    await tester.pump();

    // The check is still in flight: a neutral header, and no actions yet.
    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
    final before = tester.getCenter(
      find.widgetWithText(M3EListItem, 'Loading'),
    );
    final rows = find.byType(M3EListItem).evaluate().length;

    service.complete(ServiceState.running);
    await tester.pump();
    await tester.pump();

    expect(find.text('Running'), findsOneWidget);
    expect(find.byType(OverflowBar), findsOneWidget);
    // The answer changes the words, not the rows around them.
    expect(find.byType(M3EListItem).evaluate().length, rows);
    final after = tester.getCenter(find.widgetWithText(M3EListItem, 'Running'));
    expect(after.dx, before.dx);
    expect(after.dy, before.dy);
  });

  testWidgets('points at an unreachable service in the error color', (
    tester,
  ) async {
    const hint = 'Cannot reach the service. Start or reinstall it.';
    final backend = _ServiceBackend();
    await pump(tester, ServiceState.running, backend: backend);
    // A reachable service in service mode needs no warning.
    expect(find.text(hint), findsNothing);

    backend.status.value = BackendStatus.unavailable;
    await tester.pump();
    final text = find.text(hint);
    expect(text, findsOneWidget);
    expect(
      tester.widget<Text>(text).style?.color,
      Theme.of(tester.element(text)).colorScheme.error,
    );
  });

  testWidgets('picks the interface language', (tester) async {
    await pump(tester, ServiceState.running);
    final row = find.byType(SelectItem<Locale?>);
    expect(row, findsOneWidget);
    // The closed row shows the current choice as plain trailing text.
    expect(
      find.descendant(of: row, matching: find.text('Follow system')),
      findsOneWidget,
    );
    expect(find.byType(EditableText), findsNothing);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    // The menu names every language in its own language.
    expect(
      find.descendant(
        of: find.byType(M3EMenuPanel),
        matching: find.text('简体中文'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();

    expect(settings.interface.locale.value, const Locale('zh'));
    expect(
      find.descendant(of: row, matching: find.text('简体中文')),
      findsOneWidget,
    );
  });

  testWidgets('reads the language row left to right', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, ServiceState.running);

    final row = find.byType(SelectItem<Locale?>);
    final label = find.text('Language');
    final value = find.text('Follow system');
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: label), findsOneWidget);
    expect(find.descendant(of: row, matching: value), findsOneWidget);

    // The label leads the row and the value sits at its trailing edge, as in
    // the backend-mode rows. The 360px width also proves the row fits a phone.
    expect(tester.getTopLeft(label).dx, lessThan(tester.getTopLeft(value).dx));
    expect(
      tester.getTopRight(value).dx,
      moreOrLessEquals(tester.getTopRight(row).dx - 16, epsilon: 1),
    );
    // The setting explains itself under the headline.
    expect(find.text('The language the app shows'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fails closed when the switch is dismissed', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              answer = await confirmSwitchBackend(
                context,
                BackendKind.service,
                2,
              );
            },
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to the service?'), findsOneWidget);
    expect(find.textContaining('2 networks running'), findsOneWidget);

    // Dismissed by tapping outside: the dialog answers no.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    // The switch is reversible, so its confirm keeps the default filled look.
    final confirm = find.widgetWithText(FilledButton, 'Switch');
    expect(tester.widget<FilledButton>(confirm).style, isNull);
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  // The switch is a global side effect, not page state, so these drive the
  // controller directly instead of pumping the page.
  group('select()', () {
    /// Puts [backend] into the global signal, so a switch replaces it.
    ///
    /// [switchBackend] disposes the backend it replaces. A fake's dispose only
    /// releases its status signal, while the real FFI backend's spawns an
    /// isolate that never settles inside `flutter test`.
    void installGlobalBackend(FakeBackend backend) =>
        (backend_signals.backend as Signal<NetworkBackend>).value = backend;

    /// A fake backend running the [names] that [seedNetworks] saved.
    FakeBackend runningBackend(Iterable<String> names) {
      final backend = FakeBackend();
      for (final name in names) {
        backend.started[name] = Network()..networkName = name;
      }
      return backend;
    }

    /// A controller over [backend], whose service state is running.
    Future<BackendSettingsController> selectable(
      FakeBackend backend, {
      required Future<bool> Function(BackendKind kind, int count) confirm,
    }) async {
      messages = [];
      installGlobalBackend(backend);
      addTearDown(() async {
        await backend_signals.backend.value.dispose();
        (backend_signals.backend as Signal<NetworkBackend>).value =
            FfiBackend();
      });

      final controller = BackendSettingsController(
        showMessage: messages.add,
        confirmStopNetworks: confirm,
        probeVersion: () async => serviceVersion,
        backend: signal<NetworkBackend>(backend),
        control: SystemServiceControl(
          dataDir: '/data',
          system: _FakeSystemService(ServiceState.running),
          executable: Platform.resolvedExecutable,
        ),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      return controller;
    }

    test('keeps the networks running when the switch is declined', () async {
      await seedNetworks();
      final backend = runningBackend(['alpha', 'beta']);
      final asked = <(BackendKind, int)>[];
      final controller = await selectable(
        backend,
        confirm: (kind, count) async {
          asked.add((kind, count));
          return false;
        },
      );

      await controller.select(BackendKind.service);

      expect(asked, [(BackendKind.service, 2)]);
      expect(backend.stopped, isEmpty);
      expect(backend_signals.backend.value.kind, BackendKind.ffi);
      expect(messages, isEmpty);
    });

    test('stops the running networks before switching', () async {
      await seedNetworks();
      final backend = runningBackend(['alpha', 'beta']);
      final controller = await selectable(
        backend,
        confirm: (_, _) async => true,
      );

      await controller.select(BackendKind.service);

      expect(backend.stopped, unorderedEquals(['alpha', 'beta']));
      expect(backend_signals.backend.value.kind, BackendKind.service);
      expect(messages, isEmpty);
    });

    test('reports a stop that fails and does not switch', () async {
      await seedNetworks();
      final backend = _StubbornBackend()
        ..started['alpha'] = (Network()..networkName = 'alpha');
      final controller = await selectable(
        backend,
        confirm: (_, _) async => true,
      );

      await controller.select(BackendKind.service);

      expect(
        messages.single,
        startsWith('Could not stop the running networks:'),
      );
      expect(backend_signals.backend.value.kind, BackendKind.ffi);
    });
  });

  testWidgets('toggles the page swipe and animation', (tester) async {
    await initSettings(autostart: const UnsupportedAutostart());
    addTearDown(() => settings.interface.setPageTransitions(true));
    await pump(tester, ServiceState.running);

    await tester.ensureVisible(find.text('Page swipe and animation'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Swipe between pages on compact layouts, and animate the switch',
      ),
      findsOneWidget,
    );
    expect(settings.interface.pageTransitions.value, isTrue);

    final pageTransitions = find.descendant(
      of: find.ancestor(
        of: find.text('Page swipe and animation'),
        matching: find.byType(SwitchSegment),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(pageTransitions);
    await tester.pumpAndSettle();
    expect(settings.interface.pageTransitions.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('interface.pageTransitions'), isFalse);

    // A change made elsewhere shows on the switch.
    settings.interface.setPageTransitions(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(pageTransitions).value, isTrue);
  });
}

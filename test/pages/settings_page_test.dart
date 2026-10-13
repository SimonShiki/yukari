import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/backend/service_version.dart';
import 'package:yukari/backend/system/service_control.dart';
import 'package:yukari/backend/system/system_service.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari/models/backend.dart';
import 'package:yukari/pages/settings/settings_page.dart';

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

void main() {
  late List<String> messages;

  Future<BackendSettingsController> pump(
    WidgetTester tester,
    ServiceState state, {
    int version = serviceVersion,
  }) async {
    messages = [];
    final controller = BackendSettingsController(
      showMessage: messages.add,
      confirmStopNetworks: () async => true,
      probeVersion: () async => version,
      control: SystemServiceControl(
        dataDir: '/data',
        system: _FakeSystemService(state),
        // Any existing file stands in for the bundled service executable.
        executable: Platform.resolvedExecutable,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
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
    await pump(tester, ServiceState.running);
    expect(find.text('Running'), findsOneWidget);
    expect(find.textContaining('Version $serviceVersion'), findsOneWidget);
    expect(find.text('Reinstall'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Uninstall'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Install'), findsNothing);
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

    await tester.tap(service);
    await tester.pump();
    expect(messages, ['Grant Yukari root access first.']);
  });

  testWidgets('explains a platform without a service', (tester) async {
    await pump(tester, ServiceState.unsupported);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
  });
}

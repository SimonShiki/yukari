import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  Future<void> pump(WidgetTester tester, ServiceState state) async {
    messages = [];
    final controller = BackendSettingsController(
      showMessage: messages.add,
      confirmStopNetworks: () async => true,
      control: ServiceControl(
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
    expect(find.text('Reinstall'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Uninstall'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets('explains a platform without a service', (tester) async {
    await pump(tester, ServiceState.unsupported);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
  });
}

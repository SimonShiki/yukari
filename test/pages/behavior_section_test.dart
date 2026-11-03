import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/settings/settings_page.dart';
import 'package:yukari/pages/settings/widgets/behavior_section.dart';
import 'package:yukari/pages/settings/widgets/interface_section.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/widgets/form_section/form_segments.dart';
import 'package:yukari/widgets/form_section/section_list.dart';

import '../fake_autostart.dart';
import '../fake_service_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAutostart autostart;

  Future<void> launch({
    bool startOnBoot = true,
    bool trayAvailable = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    autostart = FakeAutostart(supported: startOnBoot);
    await initSettings(autostart: autostart);
    settings.behavior.setTrayAvailable(trayAvailable);
  }

  setUp(() => launch());

  BackendSettingsController controller({bool traySupport = true}) {
    final created = BackendSettingsController(
      showMessage: (_) {},
      confirmStopNetworks: (_, _) async => true,
      control: FakeServiceControl(supported: false),
      traySupport: traySupport,
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );
    await tester.pump();
  }

  Finder rowSwitch(String title) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(SwitchSegment),
    ),
    matching: find.byType(Switch),
  );

  Switch switchOf(WidgetTester tester, String title) =>
      tester.widget<Switch>(rowSwitch(title));

  testWidgets('shows the start on boot row where the platform supports it', (
    tester,
  ) async {
    await launch();
    await pump(
      tester,
      SectionList(
        children: [BehaviorSection(controller: controller(traySupport: false))],
      ),
    );

    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Start on boot'), findsOneWidget);
    expect(find.text('Launch Yukari when you sign in'), findsOneWidget);
    expect(find.text('Use system tray'), findsNothing);
    expect(switchOf(tester, 'Start on boot').value, isFalse);
  });

  testWidgets('shows the tray row where the platform supports a tray', (
    tester,
  ) async {
    await launch(startOnBoot: false);
    await pump(
      tester,
      SectionList(
        children: [BehaviorSection(controller: controller(traySupport: true))],
      ),
    );

    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Use system tray'), findsOneWidget);
    expect(
      find.text('Hide the window to the tray instead of quitting'),
      findsOneWidget,
    );
    expect(find.text('Start on boot'), findsNothing);
    expect(switchOf(tester, 'Use system tray').value, isTrue);
  });

  testWidgets('toggles start on boot from the row and the switch, then saves', (
    tester,
  ) async {
    await pump(
      tester,
      SectionList(children: [BehaviorSection(controller: controller())]),
    );

    await tester.tap(find.text('Start on boot'));
    expect(
      settings.behavior.startOnBoot.value,
      isTrue,
      reason: 'the signal flips at the tap',
    );
    // The row follows the signal, and the save effect runs after the frame.
    await tester.pump();
    await tester.pump();
    expect(switchOf(tester, 'Start on boot').value, isTrue);
    expect(autostart.applied, [
      false,
      true,
    ], reason: 'the OS registration follows the signal');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isTrue);

    await tester.tap(rowSwitch('Start on boot'));
    expect(settings.behavior.startOnBoot.value, isFalse);
    await tester.pump();
    await tester.pump();
    expect(switchOf(tester, 'Start on boot').value, isFalse);
    expect(autostart.applied, [false, true, false]);
    expect(prefs.getBool('behavior.startOnBoot'), isFalse);
  });

  testWidgets(
    'toggles the tray setting from the row and the switch, then saves',
    (tester) async {
      await pump(
        tester,
        SectionList(children: [BehaviorSection(controller: controller())]),
      );
      final prefs = await SharedPreferences.getInstance();

      await tester.tap(find.text('Use system tray'));
      expect(settings.behavior.useSystemTray.value, isFalse);
      await tester.pump();
      await tester.pump();
      expect(switchOf(tester, 'Use system tray').value, isFalse);
      expect(prefs.getBool('behavior.useSystemTray'), isFalse);

      await tester.tap(rowSwitch('Use system tray'));
      expect(settings.behavior.useSystemTray.value, isTrue);
      await tester.pump();
      await tester.pump();
      expect(switchOf(tester, 'Use system tray').value, isTrue);
      expect(prefs.getBool('behavior.useSystemTray'), isTrue);
    },
  );

  testWidgets('follows the tray signal when it changes elsewhere', (
    tester,
  ) async {
    await pump(
      tester,
      SectionList(children: [BehaviorSection(controller: controller())]),
    );

    settings.behavior.setUseSystemTray(false);
    await tester.pump();
    expect(switchOf(tester, 'Use system tray').value, isFalse);

    settings.behavior.setUseSystemTray(true);
    await tester.pump();
    expect(switchOf(tester, 'Use system tray').value, isTrue);
  });

  testWidgets('hides the tray row where the session has no tray icon', (
    tester,
  ) async {
    await launch(trayAvailable: false);
    await pump(
      tester,
      SectionList(children: [BehaviorSection(controller: controller())]),
    );

    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Start on boot'), findsOneWidget);
    expect(find.text('Use system tray'), findsNothing);
  });

  testWidgets('shows the tray row once the tray reports a real icon', (
    tester,
  ) async {
    await launch(startOnBoot: false, trayAvailable: false);
    final created = controller(traySupport: true);
    await pump(tester, SettingsPage(controller: created));
    expect(find.text('Behavior'), findsNothing);
    expect(find.text('Use system tray'), findsNothing);

    settings.behavior.setTrayAvailable(true);
    await tester.pump();

    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Use system tray'), findsOneWidget);
  });

  testWidgets('hides the section where the OS supports neither', (
    tester,
  ) async {
    await launch(startOnBoot: false);
    await pump(
      tester,
      SettingsPage(controller: controller(traySupport: false)),
    );

    expect(find.byType(InterfaceSection), findsOneWidget);
    expect(find.text('Behavior'), findsNothing);
    expect(find.text('Start on boot'), findsNothing);
    expect(find.text('Use system tray'), findsNothing);
  });

  testWidgets('places the behavior section after the interface section', (
    tester,
  ) async {
    await pump(tester, SettingsPage(controller: controller()));

    final interface = find.text('Interface');
    final behavior = find.text('Behavior');
    expect(interface, findsOneWidget);
    expect(behavior, findsOneWidget);
    expect(
      tester.getTopLeft(behavior).dy,
      greaterThan(tester.getTopLeft(interface).dy),
    );
    expect(find.text('Start on boot'), findsOneWidget);
    expect(find.text('Use system tray'), findsOneWidget);
  });
}

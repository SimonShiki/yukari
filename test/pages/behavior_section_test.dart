import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/settings/settings_page.dart';
import 'package:yukari/pages/settings/widgets/behavior_section.dart';
import 'package:yukari/pages/settings/widgets/interface_section.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/widgets/form_section/section_list.dart';

import '../fake_autostart.dart';
import '../fake_service_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAutostart autostart;

  Future<void> launch({bool supported = true}) async {
    SharedPreferences.setMockInitialValues({});
    autostart = FakeAutostart(supported: supported);
    await initSettings(autostart: autostart);
  }

  setUp(() => launch());

  BackendSettingsController controller() {
    final created = BackendSettingsController(
      showMessage: (_) {},
      confirmStopNetworks: (_, _) async => true,
      control: FakeServiceControl(supported: false),
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

  Switch startOnBootSwitch(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  testWidgets('shows the start on boot row when the platform supports it', (
    tester,
  ) async {
    await pump(
      tester,
      SectionList(children: [BehaviorSection(controller: controller())]),
    );

    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Start on boot'), findsOneWidget);
    expect(find.text('Launch Yukari when you sign in'), findsOneWidget);
    expect(startOnBootSwitch(tester).value, isFalse);
  });

  testWidgets('toggles from the row and the switch, then saves', (
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
    expect(startOnBootSwitch(tester).value, isTrue);
    expect(autostart.applied, [
      false,
      true,
    ], reason: 'the OS registration follows the signal');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isTrue);

    await tester.tap(find.byType(Switch));
    expect(settings.behavior.startOnBoot.value, isFalse);
    await tester.pump();
    await tester.pump();
    expect(startOnBootSwitch(tester).value, isFalse);
    expect(autostart.applied, [false, true, false]);
    expect(prefs.getBool('behavior.startOnBoot'), isFalse);
  });

  testWidgets('follows the signal when it changes elsewhere', (tester) async {
    await pump(
      tester,
      SectionList(children: [BehaviorSection(controller: controller())]),
    );

    settings.behavior.setStartOnBoot(true);
    await tester.pump();
    expect(startOnBootSwitch(tester).value, isTrue);

    settings.behavior.setStartOnBoot(false);
    await tester.pump();
    expect(startOnBootSwitch(tester).value, isFalse);
  });

  testWidgets('hides the section where the platform cannot start on boot', (
    tester,
  ) async {
    await launch(supported: false);
    await pump(tester, SettingsPage(controller: controller()));

    expect(find.byType(InterfaceSection), findsOneWidget);
    expect(find.text('Behavior'), findsNothing);
    expect(find.text('Start on boot'), findsNothing);
    expect(find.text('Launch Yukari when you sign in'), findsNothing);
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
  });
}

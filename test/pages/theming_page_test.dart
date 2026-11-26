import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart'
    show M3EColorVariant, M3EToggleButton, M3EToggleButtonGroup;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari/controllers/settings/backend_settings_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/settings/theming/palette_picker.dart';
import 'package:yukari/pages/settings/theming/theming_preview.dart';
import 'package:yukari/pages/settings/theming_page.dart';
import 'package:yukari/pages/settings/widgets/interface_section.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/autostart.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';
import 'package:yukari/widgets/form_section/section_list.dart';

import '../fake_backend.dart';
import '../fake_service_control.dart';
import '../router_support.dart';
import '../theming_test_support.dart';

/// The settings controller the interface section needs in a test.
Future<BackendSettingsController> _settingsController() async {
  final backend = signal<NetworkBackend>(FakeBackend());
  addTearDown(backend.dispose);
  final controller = BackendSettingsController(
    showMessage: (_) {},
    confirmStopNetworks: (_, _) async => true,
    probeVersion: () async => null,
    control: FakeServiceControl(supported: false),
    backend: backend,
  );
  addTearDown(controller.dispose);
  await controller.refresh();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: const UnsupportedAutostart());
    settings.theme.setVariant(M3EColorVariant.neutral);
  });

  group('interface section', () {
    testWidgets('always shows the theming row, with no system color switch', (
      tester,
    ) async {
      final controller = await _settingsController();
      await pumpApp(
        tester,
        home: Scaffold(
          body: SafeArea(
            child: SectionList(
              children: [InterfaceSection(controller: controller)],
            ),
          ),
        ),
        theme: appTheme(),
      );

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Theme settings'), findsOneWidget);
      expect(find.text('Customize more theme options'), findsOneWidget);
      expect(find.text('Use system color'), findsNothing);
    });
  });

  group('theming page', () {
    testWidgets('the system color switch saves and toggles the palette', (
      tester,
    ) async {
      expect(settings.theme.useSystemColor.value, isTrue);
      await pumpThemingPage(tester);

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.byType(PalettePicker), findsNothing);
      expect(find.text('Color style'), findsNothing);

      await tester.tap(find.text('Use system color'));
      await tester.pump();
      await tester.pump();

      expect(settings.theme.useSystemColor.value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.byType(PalettePicker), findsOneWidget);
      expect(find.text('Color style'), findsOneWidget);
      // The save effect is asynchronous; the pump lets it reach the store.
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('theme.useSystemColor'), isFalse);

      await tester.tap(find.text('Use system color'));
      await tester.pump();
      expect(settings.theme.useSystemColor.value, isTrue);
      expect(find.byType(PalettePicker), findsNothing);
    });

    testWidgets('a preset tap saves the palette and recolors the preview', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);
      final before = colorOf(tester, ThemingPreview.accentKey);
      expect(colorOf(tester, ThemingPreview.surfaceKey), scheme().surface);

      await tester.tap(swatch(ThemePalette.blue));
      await tester.pump();
      await tester.pump();

      expect(settings.theme.palette.value, ThemePalette.blue);
      expect(
        colorOf(tester, ThemingPreview.surfaceKey),
        scheme(palette: ThemePalette.blue).surface,
      );
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        scheme(palette: ThemePalette.blue).primaryContainer,
      );
      expect(colorOf(tester, ThemingPreview.accentKey), isNot(before));
      expect(
        tester.widget<PaletteSwatch>(swatch(ThemePalette.blue)).selected,
        isTrue,
      );
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.palette'), 'blue');
    });

    testWidgets('the picker scrolls to a far preset and saves it', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);
      expect(swatch(ThemePalette.blue), findsOneWidget);

      // The row is wider than the page: scroll it to the last presets.
      await tester.drag(find.byType(ListView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      await tester.tap(swatch(ThemePalette.pink));
      await tester.pump();
      await tester.pump();

      expect(settings.theme.palette.value, ThemePalette.pink);
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        scheme(palette: ThemePalette.pink).primaryContainer,
      );
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.palette'), 'pink');
    });

    testWidgets(
      'the mode buttons save the appearance and recolor the preview',
      (tester) async {
        settings.theme.setUseSystemColor(false);
        await pumpThemingPage(tester);
        expect(colorOf(tester, ThemingPreview.surfaceKey), scheme().surface);

        await tester.tap(find.byIcon(Icons.dark_mode_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(settings.theme.mode.value, ThemePreference.dark);
        expect(
          colorOf(tester, ThemingPreview.surfaceKey),
          scheme(
            brightness: Brightness.dark,
            mode: ThemePreference.dark,
          ).surface,
        );

        await tester.tap(find.byIcon(Icons.circle_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(settings.theme.mode.value, ThemePreference.oled);
        expect(colorOf(tester, ThemingPreview.surfaceKey), Colors.black);
        expect(
          colorOf(tester, ThemingPreview.accentKey),
          scheme(
            brightness: Brightness.dark,
            mode: ThemePreference.oled,
          ).primaryContainer,
        );

        await tester.tap(find.byIcon(Icons.light_mode_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(settings.theme.mode.value, ThemePreference.light);
        expect(
          colorOf(tester, ThemingPreview.surfaceKey),
          scheme(brightness: Brightness.light).surface,
        );

        await tester.pump();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme.mode'), 'light');
      },
    );

    testWidgets('the variant row saves the variant and recolors the preview', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);
      final before = colorOf(tester, ThemingPreview.accentKey);

      await tester.tap(find.text('Color style'));
      await tester.pumpAndSettle();
      expect(find.byType(M3EMenuPanel), findsOneWidget);
      await tester.tap(find.text('Vibrant').last);
      await tester.pumpAndSettle();

      expect(settings.theme.variant.value, M3EColorVariant.vibrant);
      expect(
        colorOf(tester, ThemingPreview.accentKey),
        scheme(variant: M3EColorVariant.vibrant).primaryContainer,
      );
      expect(colorOf(tester, ThemingPreview.accentKey), isNot(before));
      expect(find.text('Vibrant'), findsOneWidget);
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.variant'), 'vibrant');
    });

    testWidgets('names every preset for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);

      expect(find.bySemanticsLabel('Blue'), findsOneWidget);
      expect(find.bySemanticsLabel('Deep purple'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('layout', () {
    testWidgets('fits compact and wide layouts without overflow', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      for (final width in [320.0, 1200.0]) {
        await pumpApp(
          tester,
          home: const ThemingPage(),
          theme: appTheme(),
          size: Size(width, 900),
        );
        expect(tester.takeException(), isNull, reason: 'no overflow at $width');
      }
    });

    testWidgets('tapping a mode updates the group immediately', (tester) async {
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);
      M3EToggleButtonGroup group() => tester.widget<M3EToggleButtonGroup>(
        find.byType(M3EToggleButtonGroup),
      );
      expect(group().selectedIndex, 0);

      await tester.tap(find.byIcon(Icons.dark_mode_rounded));
      await tester.pump();

      expect(settings.theme.mode.value, ThemePreference.dark);
      expect(group().selectedIndex, 2);
      expect(
        tester
            .widget<M3EToggleButton>(find.byType(M3EToggleButton).at(2))
            .checked,
        isTrue,
      );
      expect(
        colorOf(tester, ThemingPreview.surfaceKey),
        scheme(brightness: Brightness.dark, mode: ThemePreference.dark).surface,
      );

      await tester.tap(find.byIcon(Icons.circle_rounded));
      await tester.pump();

      expect(settings.theme.mode.value, ThemePreference.oled);
      expect(group().selectedIndex, 3);
      expect(
        tester
            .widget<M3EToggleButton>(find.byType(M3EToggleButton).at(3))
            .checked,
        isTrue,
      );
      expect(colorOf(tester, ThemingPreview.surfaceKey), Colors.black);
    });
  });
}

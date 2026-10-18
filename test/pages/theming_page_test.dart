import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart'
    show M3EButtonSize, M3EColorVariant, M3EToggleButton, M3EToggleButtonGroup;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/backend/backend.dart';
import 'package:yukari/controllers/backend_settings_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/settings/theming/mode_selector.dart';
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

/// The palette row's side padding.
EdgeInsets _palettePadding(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;

/// The palette row's horizontal scroll offset.
double _paletteOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(PalettePicker),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

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
    testWidgets('the appearance group fills the row on a phone', (
      tester,
    ) async {
      await pumpThemingPage(tester);
      final selector = find.byType(ModeSelector);
      final group = find.byKey(ModeSelector.groupKey);
      final available = tester.getSize(selector).width - 32;

      expect(tester.getSize(group).width, closeTo(available, 0.5));
      expect(
        tester.getCenter(group).dx,
        closeTo(tester.getCenter(selector).dx, 0.5),
      );
      final buttons = find.byType(M3EToggleButton);
      expect(buttons, findsNWidgets(4));
      final segment = (available - 3 * 2) / 4;
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(buttons.at(i)).width, closeTo(segment, 0.5));
      }
      expect(
        tester.getRect(buttons.first).left,
        closeTo(tester.getRect(group).left, 0.5),
      );
      expect(
        tester.getRect(buttons.last).right,
        closeTo(tester.getRect(group).right, 0.5),
      );
      // Icon-only on compact: the labels are semantics/tooltips only.
      final groupWidget = tester.widget<M3EToggleButtonGroup>(
        find.byType(M3EToggleButtonGroup),
      );
      expect(groupWidget.actions, hasLength(4));
      expect(groupWidget.size, M3EButtonSize.md);
      expect(
        groupWidget.actions.every((action) => action.label == null),
        isTrue,
      );
      for (final label in ['System', 'Light', 'Dark', 'OLED']) {
        expect(
          find.descendant(of: selector, matching: find.text(label)),
          findsNothing,
        );
      }
    });

    testWidgets(
      'the appearance group is labelled, capped and centred when wide',
      (tester) async {
        await pumpApp(
          tester,
          home: const ThemingPage(),
          theme: appTheme(),
          size: const Size(1200, 900),
        );
        final selector = find.byType(ModeSelector);
        final groupFinder = find.byKey(ModeSelector.groupKey);
        final group = tester.widget<M3EToggleButtonGroup>(
          find.byType(M3EToggleButtonGroup),
        );

        expect(tester.getSize(groupFinder).width, closeTo(560, 0.5));
        expect(
          tester.getCenter(groupFinder).dx,
          closeTo(tester.getCenter(selector).dx, 0.5),
        );
        expect(group.selectedIndex, 0);
        expect(group.actions, hasLength(4));
        expect(group.size, M3EButtonSize.sm);
        final segment = (560 - 3 * 2) / 4;
        for (final action in group.actions) {
          expect(action.width, closeTo(segment, 0.5));
          expect(action.label, isNotNull);
          expect(action.semanticLabel, isNotNull);
          expect(action.tooltip, isNotNull);
        }
        // The wide group shows the localized labels next to the icons.
        for (final label in ['System', 'Light', 'Dark', 'OLED']) {
          expect(
            find.descendant(of: selector, matching: find.text(label)),
            findsWidgets,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the wide group fits without overflow up to 1600', (
      tester,
    ) async {
      for (final width in [600.0, 800.0, 1200.0, 1600.0]) {
        await pumpApp(
          tester,
          home: const ThemingPage(),
          theme: appTheme(),
          size: Size(width, 900),
        );
        final selector = find.byType(ModeSelector);
        final groupFinder = find.byKey(ModeSelector.groupKey);
        expect(
          tester.getSize(groupFinder).width,
          closeTo(560, 0.5),
          reason: 'group is capped at $width wide',
        );
        expect(
          tester.getCenter(groupFinder).dx,
          closeTo(tester.getCenter(selector).dx, 0.5),
          reason: 'group is centred at $width wide',
        );
        final group = tester.widget<M3EToggleButtonGroup>(
          find.byType(M3EToggleButtonGroup),
        );
        expect(group.size, M3EButtonSize.sm);
        for (final action in group.actions) {
          expect(action.label, isNotNull, reason: 'labels at $width wide');
          expect(action.width, closeTo((560 - 6) / 4, 0.5));
        }
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

    testWidgets('the layout fits a 320 wide page', (tester) async {
      settings.theme.setUseSystemColor(false);
      await pumpApp(
        tester,
        home: const ThemingPage(),
        theme: appTheme(),
        size: const Size(320, 900),
      );
      final selector = find.byType(ModeSelector);
      final group = find.byKey(ModeSelector.groupKey);
      final available = tester.getSize(selector).width - 32;

      expect(tester.getSize(group).width, closeTo(available, 0.5));
      final buttons = find.byType(M3EToggleButton);
      expect(buttons, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(
          tester.getSize(buttons.at(i)).width,
          closeTo((available - 6) / 4, 0.5),
        );
      }
      expect(
        tester.getRect(buttons.first).left,
        closeTo(tester.getRect(group).left, 0.5),
      );
      expect(
        tester.getRect(buttons.last).right,
        closeTo(tester.getRect(group).right, 0.5),
      );

      final padding = _palettePadding(tester);
      expect(padding.left, 16);
      expect(padding.right, 16);
      expect(_paletteOffset(tester), 0);
      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(_paletteOffset(tester), greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the palette row fits before it scrolls', (tester) async {
      settings.theme.setUseSystemColor(false);
      const rowWidth = 8 * 72 + 7 * 16;

      // Just below the row width: edge padding and scrolling.
      await pumpApp(
        tester,
        home: const ThemingPage(),
        theme: appTheme(),
        size: const Size(720 - 8, 900),
      );
      expect(
        tester.getSize(find.byType(PalettePicker)).width,
        closeTo(rowWidth - 8, 0.5),
      );
      expect(_palettePadding(tester).left, 16);
      expect(_palettePadding(tester).right, 16);
      await tester.drag(find.byType(ListView), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(_paletteOffset(tester), greaterThan(0));

      // Just above the row width: centred with less than a gap of padding and
      // no scrolling.
      await pumpApp(
        tester,
        home: const ThemingPage(),
        theme: appTheme(),
        size: const Size(720 + 12, 900),
      );
      expect(
        tester.getSize(find.byType(PalettePicker)).width,
        closeTo(rowWidth + 12, 0.5),
      );
      expect(_palettePadding(tester).left, closeTo(6, 0.5));
      expect(_palettePadding(tester).right, closeTo(6, 0.5));
      final pickerRect = tester.getRect(find.byType(PalettePicker));
      final first = tester.getRect(swatch(ThemePalette.deepPurple));
      final last = tester.getRect(swatch(ThemePalette.red));
      expect((first.left + last.right) / 2, closeTo(pickerRect.center.dx, 0.5));
      await tester.drag(find.byType(ListView), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(_paletteOffset(tester), 0);

      // Exactly the row width: no padding at all, still no scrolling.
      await pumpApp(
        tester,
        home: const ThemingPage(),
        theme: appTheme(),
        size: const Size(720, 900),
      );
      expect(_palettePadding(tester).left, 0);
      expect(_palettePadding(tester).right, 0);
      expect(_paletteOffset(tester), 0);
    });

    testWidgets('the palette row is centred when there is room', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      await pumpApp(
        tester,
        home: const ThemingPage(),
        theme: appTheme(),
        size: const Size(1200, 900),
      );
      final picker = find.byType(PalettePicker);
      final list = tester.widget<ListView>(find.byType(ListView));
      final padding = list.padding! as EdgeInsets;
      final pickerRect = tester.getRect(picker);
      final first = tester.getRect(swatch(ThemePalette.deepPurple));
      final last = tester.getRect(swatch(ThemePalette.red));

      expect(padding.left, closeTo(76, 0.5));
      expect(padding.right, closeTo(76, 0.5));
      expect(first.left - pickerRect.left, closeTo(76, 0.5));
      expect(pickerRect.right - last.right, closeTo(76, 0.5));
      expect((first.left + last.right) / 2, closeTo(pickerRect.center.dx, 0.5));
    });

    testWidgets('the palette row scrolls with 16dp padding on a phone', (
      tester,
    ) async {
      settings.theme.setUseSystemColor(false);
      await pumpThemingPage(tester);
      final picker = find.byType(PalettePicker);
      final list = tester.widget<ListView>(find.byType(ListView));
      final padding = list.padding! as EdgeInsets;

      expect(padding.left, 16);
      expect(padding.right, 16);
      expect(list.scrollDirection, Axis.horizontal);
      expect(tester.getSize(picker).width, lessThan(8 * 72 + 7 * 16));
      final scrollable = find.descendant(
        of: picker,
        matching: find.byType(Scrollable),
      );
      double offset() =>
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset(), 0);
      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(offset(), greaterThan(0));
    });
  });
}

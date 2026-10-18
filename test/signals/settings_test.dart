import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/signals/settings.dart';

import '../fake_autostart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeAutostart> launch([FakeAutostart? autostart]) async {
    final fake = autostart ?? FakeAutostart();
    await initSettings(autostart: fake);
    return fake;
  }

  test('updates a setting before initialization without persisting', () async {
    settings.behavior.setStartOnBoot(true);
    settings.theme.setMode(ThemePreference.dark);
    settings.interface.setPageTransitions(false);

    expect(settings.behavior.startOnBoot.value, isTrue);
    expect(settings.theme.mode.value, ThemePreference.dark);
    expect(settings.interface.pageTransitions.value, isFalse);
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);

    settings.behavior.setStartOnBoot(false);
    settings.theme.setMode(ThemePreference.system);
    settings.interface.setPageTransitions(true);
  });

  test('starts from the defaults', () async {
    await launch();

    expect(settings.interface.locale.value, isNull);
    expect(settings.interface.pageTransitions.value, isTrue);
    expect(settings.theme.useSystemColor.value, isTrue);
    expect(settings.theme.palette.value, ThemePalette.deepPurple);
    expect(settings.theme.variant.value, M3EColorVariant.fidelity);
    expect(settings.theme.mode.value, ThemePreference.system);
    expect(settings.behavior.startOnBoot.value, isFalse);
    expect(settings.behavior.useSystemTray.value, isTrue);
    expect(
      settings.behavior.trayAvailable.value,
      isFalse,
      reason: 'the tray reports a real icon after startup',
    );
    expect(settings.workingMode.backend.value, BackendKind.ffi);
  });

  test('loads every saved setting', () async {
    SharedPreferences.setMockInitialValues({
      'locale': 'zh',
      'interface.pageTransitions': false,
      'theme.useSystemColor': false,
      'theme.palette': 'teal',
      'theme.variant': 'expressive',
      'theme.mode': 'oled',
      'behavior.startOnBoot': true,
      'behavior.useSystemTray': false,
      'backend': 'service',
    });

    final autostart = await launch();

    expect(settings.interface.locale.value, const Locale('zh'));
    expect(settings.interface.pageTransitions.value, isFalse);
    expect(settings.theme.useSystemColor.value, isFalse);
    expect(settings.theme.palette.value, ThemePalette.teal);
    expect(settings.theme.variant.value, M3EColorVariant.expressive);
    expect(settings.theme.mode.value, ThemePreference.oled);
    expect(settings.behavior.startOnBoot.value, isTrue);
    expect(settings.behavior.useSystemTray.value, isFalse);
    expect(settings.workingMode.backend.value, BackendKind.service);
    expect(
      autostart.applied,
      [true],
      reason: 'the saved start on boot is applied on load',
    );
  });

  test('starts from the defaults when a saved value is unknown', () async {
    SharedPreferences.setMockInitialValues({
      'locale': 'xx',
      'interface.pageTransitions': 'yes',
      'theme.useSystemColor': 'maybe',
      'theme.palette': 'mauve',
      'theme.variant': 'loud',
      'theme.mode': 'dusk',
      'behavior.startOnBoot': 'yes',
      'behavior.useSystemTray': 'yes',
      'backend': 'remote',
    });

    await launch();

    expect(settings.interface.locale.value, isNull);
    expect(settings.interface.pageTransitions.value, isTrue);
    expect(settings.theme.useSystemColor.value, isTrue);
    expect(settings.theme.palette.value, ThemePalette.deepPurple);
    expect(settings.theme.variant.value, M3EColorVariant.fidelity);
    expect(settings.theme.mode.value, ThemePreference.system);
    expect(settings.behavior.startOnBoot.value, isFalse);
    expect(settings.behavior.useSystemTray.value, isTrue);
    expect(settings.workingMode.backend.value, BackendKind.ffi);
  });

  test('saves each setting as it changes', () async {
    await launch();

    settings.interface.setLocale(const Locale('zh'));
    settings.interface.setPageTransitions(false);
    settings.theme.setUseSystemColor(false);
    settings.theme.setPalette(ThemePalette.pink);
    settings.theme.setVariant(M3EColorVariant.vibrant);
    settings.theme.setMode(ThemePreference.dark);
    settings.behavior.setStartOnBoot(true);
    settings.behavior.setUseSystemTray(false);
    settings.workingMode.setBackend(BackendKind.service);
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'zh');
    expect(prefs.getBool('interface.pageTransitions'), isFalse);
    expect(prefs.getBool('theme.useSystemColor'), isFalse);
    expect(prefs.getString('theme.palette'), 'pink');
    expect(prefs.getString('theme.variant'), 'vibrant');
    expect(prefs.getString('theme.mode'), 'dark');
    expect(prefs.getBool('behavior.startOnBoot'), isTrue);
    expect(prefs.getBool('behavior.useSystemTray'), isFalse);
    expect(prefs.getString('backend'), 'service');

    settings.interface.setLocale(null);
    await pumpEventQueue();
    expect(prefs.getString('locale'), isNull, reason: 'follow system clears it');
  });

  test('restores every setting after a restart', () async {
    await launch();

    settings.interface.setLocale(const Locale('zh'));
    settings.interface.setPageTransitions(false);
    settings.theme.setUseSystemColor(false);
    settings.theme.setPalette(ThemePalette.green);
    settings.theme.setVariant(M3EColorVariant.fidelity);
    settings.theme.setMode(ThemePreference.light);
    settings.behavior.setStartOnBoot(true);
    settings.behavior.setUseSystemTray(false);
    settings.workingMode.setBackend(BackendKind.service);
    await pumpEventQueue();

    final restarted = FakeAutostart();
    await initSettings(autostart: restarted);

    expect(settings.interface.locale.value, const Locale('zh'));
    expect(settings.interface.pageTransitions.value, isFalse);
    expect(settings.theme.useSystemColor.value, isFalse);
    expect(settings.theme.palette.value, ThemePalette.green);
    expect(settings.theme.variant.value, M3EColorVariant.fidelity);
    expect(settings.theme.mode.value, ThemePreference.light);
    expect(settings.behavior.startOnBoot.value, isTrue);
    expect(settings.behavior.useSystemTray.value, isFalse);
    expect(settings.workingMode.backend.value, BackendKind.service);
    expect(restarted.applied, [true], reason: 'it is applied at startup again');
  });

  test('replaces its effects when initialized again', () async {
    final first = await launch();
    final second = await launch();

    settings.behavior.setStartOnBoot(true);
    await pumpEventQueue();

    expect(first.applied, [false], reason: 'the old effects are gone');
    expect(second.applied, [false, true]);
  });

  test('exposes every setting as a read-only signal', () async {
    await launch();

    expect(settings.interface.locale, isA<ReadonlySignal<Locale?>>());
    expect(settings.interface.pageTransitions, isA<ReadonlySignal<bool>>());
    expect(settings.theme.useSystemColor, isA<ReadonlySignal<bool>>());
    expect(settings.theme.palette, isA<ReadonlySignal<ThemePalette>>());
    expect(settings.theme.variant, isA<ReadonlySignal<M3EColorVariant>>());
    expect(settings.theme.mode, isA<ReadonlySignal<ThemePreference>>());
    expect(settings.behavior.startOnBoot, isA<ReadonlySignal<bool>>());
    expect(settings.behavior.useSystemTray, isA<ReadonlySignal<bool>>());
    expect(settings.behavior.trayAvailable, isA<ReadonlySignal<bool>>());
    expect(settings.workingMode.backend, isA<ReadonlySignal<BackendKind>>());
  });

  test('notifies subscribers when a setting changes', () async {
    await launch();
    final seen = <ThemePreference>[];
    final stop = effect(() => seen.add(settings.theme.mode.value));
    addTearDown(stop);

    settings.theme.setMode(ThemePreference.dark);

    expect(seen, [ThemePreference.system, ThemePreference.dark]);
  });
}

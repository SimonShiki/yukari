import 'dart:async';
import 'dart:ui' show Locale;

import 'package:m3e_core/m3e_core.dart' show M3EColorVariant;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import '../system/autostart.dart';
import '../system/tray_support.dart';

part 'settings_groups.dart';
part 'settings_start_on_boot.dart';
part 'settings_storage.dart';

/// The app's settings: every preference that persists across launches.
///
/// **Initialization**: Call [initSettings] once at app startup.
final settings = Settings();

/// The settings page's persisted values, grouped by where they show.
///
/// Backing signals are private: settings change through the `set…` actions,
/// which persist through effects registered by [initSettings].
class Settings {
  final InterfaceSettings interface = InterfaceSettings();
  final ThemeSettings theme = ThemeSettings();
  final BehaviorSettings behavior = BehaviorSettings();
  final WorkingModeSettings workingMode = WorkingModeSettings();

  SharedPreferences? _prefs;
  final List<EffectCleanup> _effects = [];
  bool _restoring = false;
  late _StartOnBootApplier _startOnBoot;

  void _restore(SharedPreferences prefs, Autostart autostart) {
    _prefs = prefs;
    interface._locale.value = _storedLocale(prefs);
    interface._pageTransitions.value = _storedBool(
      prefs,
      _pageTransitionsKey,
      true,
    );
    theme._useSystemColor.value = _storedBool(prefs, _useSystemColorKey, true);
    theme._palette.value = _storedEnum(
      prefs,
      _paletteKey,
      ThemePalette.values,
      ThemePalette.deepPurple,
    );
    theme._variant.value = _storedEnum(
      prefs,
      _variantKey,
      M3EColorVariant.values,
      M3EColorVariant.fidelity,
    );
    theme._mode.value = _storedEnum(
      prefs,
      _modeKey,
      ThemePreference.values,
      ThemePreference.system,
    );
    behavior._autostart = autostart;
    _startOnBoot = _StartOnBootApplier(behavior._startOnBoot, autostart);
    behavior._startOnBoot.value = _storedBool(prefs, _startOnBootKey, false);
    behavior._useSystemTray.value = _storedBool(prefs, _useSystemTrayKey, true);
    // Discovered by the tray at startup, never saved.
    behavior._trayAvailable.value = false;
    workingMode._backend.value = _storedEnum(
      prefs,
      _backendKey,
      BackendKind.values,
      BackendKind.ffi,
    );
  }

  /// Registers one effect per setting, replacing the effects of a previous
  /// [initSettings] call so nothing is saved twice.
  void _registerEffects() {
    for (final dispose in _effects) {
      dispose();
    }
    _effects.clear();
    _persist(interface._locale, (prefs, locale) async {
      if (locale == null) {
        await prefs.remove(_localeKey);
      } else {
        await prefs.setString(_localeKey, locale.toLanguageTag());
      }
    });
    _persist(
      interface._pageTransitions,
      (prefs, value) => prefs.setBool(_pageTransitionsKey, value),
    );
    _persist(
      theme._useSystemColor,
      (prefs, value) => prefs.setBool(_useSystemColorKey, value),
    );
    _persist(
      theme._palette,
      (prefs, value) => prefs.setString(_paletteKey, value.name),
    );
    _persist(
      theme._variant,
      (prefs, value) => prefs.setString(_variantKey, value.name),
    );
    _persist(
      theme._mode,
      (prefs, value) => prefs.setString(_modeKey, value.name),
    );
    _effects.add(
      effect(() {
        final enabled = behavior._startOnBoot.value;
        final prefs = _prefs;
        if (_restoring || prefs == null) return;
        _startOnBoot.request(prefs, enabled);
      }),
    );
    _persist(
      behavior._useSystemTray,
      (prefs, value) => prefs.setBool(_useSystemTrayKey, value),
    );
    _persist(
      workingMode._backend,
      (prefs, value) => prefs.setString(_backendKey, value.name),
    );
  }

  void _persist<T>(
    Signal<T> source,
    Future<void> Function(SharedPreferences prefs, T value) write,
  ) {
    _effects.add(
      effect(() {
        final value = source.value;
        final prefs = _prefs;
        if (_restoring || prefs == null) return;
        unawaited(write(prefs, value));
      }),
    );
  }
}

/// Loads the saved settings, then keeps them saved and applied as they change.
///
/// Call once at app startup, before running the app. Settings changed before
/// this only update the signals and are not persisted. Tests pass an
/// [autostart] fake and may call it again: the previous effects are replaced,
/// not stacked.
Future<void> initSettings({Autostart? autostart}) async {
  final prefs = await SharedPreferences.getInstance();
  // Loading must not write the defaults back over what is stored: the first
  // run of each new persistence effect is skipped.
  settings._restoring = true;
  settings._restore(prefs, autostart ?? platformAutostart());
  settings._registerEffects();
  settings._restoring = false;
  await settings._startOnBoot.applyLoaded(
    prefs,
    settings.behavior._startOnBoot.value,
  );
}

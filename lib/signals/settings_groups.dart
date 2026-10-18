part of 'settings.dart';

/// The language the app shows.
class InterfaceSettings {
  final Signal<Locale?> _locale = signal(null);
  final Signal<bool> _pageTransitions = signal(true);

  /// The language the user picked, or null to follow the system.
  ReadonlySignal<Locale?> get locale => _locale;

  /// Shows the app in [locale], or in the system language when null.
  void setLocale(Locale? locale) => _locale.value = locale;

  /// Whether top pages can be switched with a swipe (compact layouts) and
  /// animate the switch.
  ReadonlySignal<bool> get pageTransitions => _pageTransitions;

  /// Enables the top-page swipe gesture and switching animation.
  void setPageTransitions(bool enabled) => _pageTransitions.value = enabled;
}

/// How the app draws its theme.
class ThemeSettings {
  final Signal<bool> _useSystemColor = signal(true);
  final Signal<ThemePalette> _palette = signal(ThemePalette.deepPurple);
  final Signal<M3EColorVariant> _variant = signal(M3EColorVariant.fidelity);
  final Signal<ThemePreference> _mode = signal(ThemePreference.system);

  /// Whether to draw with the OS dynamic colours (Material You).
  ReadonlySignal<bool> get useSystemColor => _useSystemColor;

  /// The seed colour the app generates its scheme from.
  ReadonlySignal<ThemePalette> get palette => _palette;

  /// The shape of the generated colour scheme.
  ReadonlySignal<M3EColorVariant> get variant => _variant;

  /// Which appearance the app uses.
  ReadonlySignal<ThemePreference> get mode => _mode;

  /// Draws with the OS dynamic colours when [useSystemColor] is true.
  void setUseSystemColor(bool useSystemColor) =>
      _useSystemColor.value = useSystemColor;

  /// Generates the scheme from [palette].
  void setPalette(ThemePalette palette) => _palette.value = palette;

  /// Generates the scheme with [variant].
  void setVariant(M3EColorVariant variant) => _variant.value = variant;

  /// Shows the app with [mode].
  void setMode(ThemePreference mode) => _mode.value = mode;
}

/// What the app does around launch and sign-in.
class BehaviorSettings {
  final Signal<bool> _startOnBoot = signal(false);
  final Signal<bool> _useSystemTray = signal(true);
  final Signal<bool> _trayAvailable = signal(false);
  Autostart _autostart = const UnsupportedAutostart();

  /// Whether the app starts when the user signs in.
  ///
  /// Changing it applies to the OS first; if the OS refuses, the signal
  /// returns to the last value the OS accepted.
  ReadonlySignal<bool> get startOnBoot => _startOnBoot;

  /// Whether the OS can start the app at sign-in. The settings page hides the
  /// option when it cannot.
  bool get startOnBootSupported => _autostart.supported;

  /// Starts the app at sign-in when [enabled].
  void setStartOnBoot(bool enabled) => _startOnBoot.value = enabled;

  /// Whether closing the window hides the app in the system tray instead of
  /// quitting it.
  ReadonlySignal<bool> get useSystemTray => _useSystemTray;

  /// Whether the OS can show the app in a system tray. The settings page hides
  /// the option when it cannot.
  bool get traySupported => systemTraySupported;

  /// Whether this session actually has a tray icon the app can hide the window
  /// in. The OS may support trays while the desktop shows none, as on GNOME
  /// without its AppIndicator extension, so the tray controller reports the
  /// real answer after trying; the settings page hides the option until then.
  ReadonlySignal<bool> get trayAvailable => _trayAvailable;

  /// Hides the window in the system tray when [enabled].
  void setUseSystemTray(bool enabled) => _useSystemTray.value = enabled;

  /// Records whether a tray icon exists in this session.
  void setTrayAvailable(bool available) => _trayAvailable.value = available;
}

/// Where the app runs its networks.
class WorkingModeSettings {
  final Signal<BackendKind> _backend = signal(BackendKind.ffi);

  /// The backend the user chose to run instances in.
  ReadonlySignal<BackendKind> get backend => _backend;

  /// Runs the networks in [kind] from now on.
  void setBackend(BackendKind kind) => _backend.value = kind;
}

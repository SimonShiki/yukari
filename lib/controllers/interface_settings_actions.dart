part of 'backend_settings_controller.dart';

extension InterfaceSettingsActions on BackendSettingsController {
  /// The language the user picked, or null to follow the system.
  ReadonlySignal<Locale?> get language => settings.interface.locale;

  /// Shows the app in [locale], or in the system language when null.
  void selectLanguage(Locale? locale) => settings.interface.setLocale(locale);

  /// Whether the top pages follow a swipe and slide when switched.
  ReadonlySignal<bool> get pageTransitions =>
      settings.interface.pageTransitions;

  /// Enables or disables the top-page swipe gesture and switching animation.
  void setPageTransitions(bool enabled) =>
      settings.interface.setPageTransitions(enabled);

  /// Whether the app starts when the user signs in.
  ReadonlySignal<bool> get startOnBoot => settings.behavior.startOnBoot;

  /// Whether this platform can launch the app at sign-in. The settings page
  /// hides the option where it cannot, as on Android.
  bool get startOnBootSupported => settings.behavior.startOnBootSupported;

  /// Starts the app at sign-in when [startOnBoot] is true.
  void setStartOnBoot(bool startOnBoot) =>
      settings.behavior.setStartOnBoot(startOnBoot);

  /// Whether this platform can keep the app in a system tray. The settings page
  /// hides the option where it cannot, as on Android.
  bool get traySupported => _traySupported ?? settings.behavior.traySupported;

  /// Whether the App mode runs through Android's system VPN, which is what
  /// limits it: the settings page explains that instead of the desktop
  /// privileges it does not need.
  bool get appUsesSystemVpn => _appUsesSystemVpn ?? Platform.isAndroid;

  /// Whether this session actually has a tray icon to hide the window in. The
  /// settings page hides the option until the tray reports one.
  ReadonlySignal<bool> get trayAvailable => settings.behavior.trayAvailable;

  /// Whether closing the window hides the app in the system tray.
  ReadonlySignal<bool> get useSystemTray => settings.behavior.useSystemTray;

  /// Hides the window in the system tray when [useSystemTray] is true.
  void setUseSystemTray(bool useSystemTray) =>
      settings.behavior.setUseSystemTray(useSystemTray);
}

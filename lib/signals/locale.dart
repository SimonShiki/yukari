import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import '../l10n/l10n.dart';

/// Private backing signal for the language the user picked.
/// Use [preferredLocale] for readonly access and [setPreferredLocale] for
/// changes.
final Signal<Locale?> _preferred = signal(null);

/// The language the user picked, or null to follow the system.
///
/// **Initialization**: Call [initLocale] once at app startup.
///
/// **Mutation**: Use [setPreferredLocale]; the choice persists across
/// launches.
ReadonlySignal<Locale?> get preferredLocale => _preferred;

final _systemLocales = signal(PlatformDispatcher.instance.locales);

/// The language the app shows: the user's pick, else the closest system
/// language, else English.
final appLocale = computed(
  () =>
      _preferred.value ??
      basicLocaleListResolution(
        _systemLocales.value,
        AppLocalizations.supportedLocales,
      ),
);

/// The app's strings in [appLocale], for code without a [BuildContext].
/// Widgets use `context.l10n` instead.
final l10n = computed(() => lookupAppLocalizations(appLocale.value));

const _localeKey = 'locale';

/// Restores the language the user picked and follows system changes.
Future<void> initLocale() async {
  WidgetsBinding.instance.addObserver(_SystemLocaleObserver());
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_localeKey);
  _preferred.value = _supported(saved);
}

/// Shows the app in [locale], or in the system language when null.
Future<void> setPreferredLocale(Locale? locale) async {
  _preferred.value = locale;
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove(_localeKey);
  } else {
    await prefs.setString(_localeKey, locale.toLanguageTag());
  }
}

Locale? _supported(String? tag) {
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.toLanguageTag() == tag) return locale;
  }
  return null;
}

class _SystemLocaleObserver with WidgetsBindingObserver {
  @override
  void didChangeLocales(List<Locale>? locales) =>
      _systemLocales.value = locales ?? const [];
}

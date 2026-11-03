import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:signals/signals.dart';

import '../l10n/l10n.dart';
import 'settings.dart';

final _systemLocales = signal(PlatformDispatcher.instance.locales);

/// The language the app shows: the user's pick, else the closest system
/// language, else English.
final appLocale = computed(
  () =>
      settings.interface.locale.value ??
      basicLocaleListResolution(
        _systemLocales.value,
        AppLocalizations.supportedLocales,
      ),
);

/// The app's strings in [appLocale], for code without a [BuildContext].
/// Widgets use `context.l10n` instead.
final l10n = computed(() => lookupAppLocalizations(appLocale.value));

bool _followingSystemLocales = false;

/// Follows the OS language while the user has not picked one.
///
/// Call once at app startup; later calls do nothing.
void initLocale() {
  if (_followingSystemLocales) return;
  _followingSystemLocales = true;
  WidgetsBinding.instance.addObserver(_SystemLocaleObserver());
}

class _SystemLocaleObserver with WidgetsBindingObserver {
  @override
  void didChangeLocales(List<Locale>? locales) =>
      _systemLocales.value = locales ?? const [];
}

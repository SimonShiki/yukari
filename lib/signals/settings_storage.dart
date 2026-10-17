part of 'settings.dart';

const _localeKey = 'locale';
const _pageTransitionsKey = 'interface.pageTransitions';
const _backendKey = 'backend';
const _useSystemColorKey = 'theme.useSystemColor';
const _paletteKey = 'theme.palette';
const _variantKey = 'theme.variant';
const _modeKey = 'theme.mode';
const _startOnBootKey = 'behavior.startOnBoot';

Locale? _storedLocale(SharedPreferences prefs) {
  final saved = prefs.get(_localeKey);
  if (saved is! String) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.toLanguageTag() == saved) return locale;
  }
  return null;
}

T _storedEnum<T extends Enum>(
  SharedPreferences prefs,
  String key,
  List<T> values,
  T fallback,
) {
  final saved = prefs.get(key);
  return saved is String ? values.asNameMap()[saved] ?? fallback : fallback;
}

bool _storedBool(SharedPreferences prefs, String key, bool fallback) {
  final saved = prefs.get(key);
  return saved is bool ? saved : fallback;
}

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The app's strings in the language it shows.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

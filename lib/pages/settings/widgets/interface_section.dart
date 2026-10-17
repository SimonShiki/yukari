import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/select_item/select_item.dart';

/// Picks the language the app shows.
class InterfaceSection extends StatelessWidget {
  const InterfaceSection({
    super.key,
    required this.language,
    required this.onChanged,
  });

  /// The language the user picked, or null to follow the system.
  final ReadonlySignal<Locale?> language;

  /// Persists a picked language through the settings controller.
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.settingsInterface,
      icon: Icons.palette_outlined,
      children: [
        SignalBuilder(
          builder: (context) => SelectItem<Locale?>(
            icon: Icons.translate_rounded,
            label: l10n.settingsLanguage,
            supportingText: l10n.settingsLanguageDescription,
            value: language.value,
            options: [null, ...AppLocalizations.supportedLocales],
            // Every language is named in its own language.
            labelOf: (locale) => locale == null
                ? l10n.settingsLanguageSystem
                : lookupAppLocalizations(locale).languageName,
            onSelected: onChanged,
          ),
        ),
      ],
    );
  }
}

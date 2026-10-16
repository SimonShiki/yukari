import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';

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
        // Like the backend-mode rows: the label on the left, the control on
        // the right, instead of a floating label inside the field.
        M3EListItem(
          headline: Text(l10n.settingsLanguage),
          trailing: SignalBuilder(
            builder: (context) => DropdownMenu<Locale?>(
              // Bounded so the row still fits a 360px-wide window: left to
              // itself the menu sizes to its widest entry, about 300px.
              width: 200,
              initialSelection: language.value,
              leadingIcon: const Icon(Icons.translate_rounded),
              onSelected: onChanged,
              dropdownMenuEntries: [
                DropdownMenuEntry<Locale?>(
                  value: null,
                  label: l10n.settingsLanguageSystem,
                ),
                for (final locale in AppLocalizations.supportedLocales)
                  DropdownMenuEntry<Locale?>(
                    value: locale,
                    // Every language is named in its own language.
                    label: lookupAppLocalizations(locale).languageName,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

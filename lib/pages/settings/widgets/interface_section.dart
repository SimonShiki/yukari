import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/l10n.dart';
import '../../../signals/locale.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';

/// How the app looks and reads, such as its language.
class InterfaceSection extends StatelessWidget {
  const InterfaceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.settingsInterface,
      icon: Icons.palette_outlined,
      children: [
        FieldSegment(
          child: SignalBuilder(
            builder: (context) => DropdownMenu<Locale?>(
              expandedInsets: EdgeInsets.zero,
              label: Text(l10n.settingsLanguage),
              leadingIcon: const Icon(Icons.translate_rounded),
              initialSelection: preferredLocale.value,
              dropdownMenuEntries: [
                DropdownMenuEntry(
                  value: null,
                  label: l10n.settingsLanguageSystem,
                ),
                for (final locale in AppLocalizations.supportedLocales)
                  DropdownMenuEntry(
                    value: locale,
                    // Each language by its own name, so anyone finds theirs.
                    label: lookupAppLocalizations(locale).languageName,
                  ),
              ],
              onSelected: setPreferredLocale,
            ),
          ),
        ),
      ],
    );
  }
}

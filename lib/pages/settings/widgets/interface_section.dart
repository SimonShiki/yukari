import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/backend_settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/select_item/select_item.dart';

/// Picks the language the app shows, and opens the theming page.
class InterfaceSection extends StatelessWidget {
  const InterfaceSection({super.key, required this.controller});

  final BackendSettingsController controller;

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
            value: controller.language.value,
            options: [null, ...AppLocalizations.supportedLocales],
            // Every language is named in its own language.
            labelOf: (locale) => locale == null
                ? l10n.settingsLanguageSystem
                : lookupAppLocalizations(locale).languageName,
            onSelected: controller.selectLanguage,
          ),
        ),
        // The theming page holds the color options; this row always leads
        // there.
        InkWell(
          onTap: () => context.push('/settings/theming'),
          child: M3EListItem(
            leading: const Icon(Icons.palette_outlined),
            headline: Text(l10n.settingsThemeSettings),
            supportingText: Text(l10n.settingsThemeSettingsDescription),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        // Only the row that changes state rebuilds.
        SignalBuilder(
          builder: (context) => SwitchSegment(
            icon: Icons.swipe_rounded,
            title: l10n.settingsPageTransitions,
            subtitle: l10n.settingsPageTransitionsDescription,
            value: controller.pageTransitions.value,
            onChanged: controller.setPageTransitions,
          ),
        ),
      ],
    );
  }
}

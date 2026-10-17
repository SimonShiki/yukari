import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/theming_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/form_section/form_section.dart';
import '../../widgets/form_section/form_segments.dart';
import '../../widgets/form_section/section_list.dart';
import 'theming/mode_selector.dart';
import 'theming/palette_picker.dart';
import 'theming/theming_preview.dart';
import 'theming/variant_selector.dart';

/// The full theming page: a live preview, then the color scheme options and
/// the appearance picker, each saving through the theme settings as it
/// changes.
class ThemingPage extends StatefulWidget {
  const ThemingPage({super.key});

  @override
  State<ThemingPage> createState() => _ThemingPageState();
}

class _ThemingPageState extends State<ThemingPage> {
  final ThemingController _controller = ThemingController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsThemeSettings)),
      body: SafeArea(
        child: SectionList(
          children: [
            ThemingPreview(controller: _controller),
            FormSection(
              title: l10n.themingPalette,
              icon: Icons.palette_outlined,
              segments: false,
              children: [
                SignalBuilder(builder: (context) => _schemeOptions(l10n)),
              ],
            ),
            FormSection(
              title: l10n.themingMode,
              icon: Icons.brightness_6_outlined,
              segments: false,
              children: [ModeSelector(controller: _controller)],
            ),
          ],
        ),
      ),
    );
  }

  /// The system color switch, then the palette and its style only while the
  /// palette generates the colors.
  Widget _schemeOptions(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FormSegments(
        children: [
          SwitchSegment(
            icon: Icons.auto_awesome_outlined,
            title: l10n.settingsUseSystemColor,
            subtitle: l10n.settingsUseSystemColorDescription,
            value: _controller.useSystemColor.value,
            onChanged: _controller.setUseSystemColor,
          ),
        ],
      ),
      if (!_controller.useSystemColor.value) ...[
        const SizedBox(height: 16),
        PalettePicker(controller: _controller),
        const SizedBox(height: 16),
        VariantSelector(controller: _controller),
      ],
    ],
  );
}

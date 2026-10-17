import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/theming_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/select_item/select_item.dart';

/// The color variant row: how the seed color shapes the generated scheme.
class VariantSelector extends StatelessWidget {
  const VariantSelector({super.key, required this.controller});

  final ThemingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SignalBuilder(
      builder: (context) => FormSegments(
        children: [
          SelectItem<M3EColorVariant>(
            icon: Icons.format_paint_outlined,
            label: l10n.themingVariant,
            supportingText: l10n.themingVariantDescription,
            value: controller.variant.value,
            options: M3EColorVariant.values,
            labelOf: (variant) => _label(l10n, variant),
            onSelected: controller.selectVariant,
          ),
        ],
      ),
    );
  }
}

/// The user-facing name of [variant].
String _label(AppLocalizations l10n, M3EColorVariant variant) =>
    switch (variant) {
      M3EColorVariant.tonalSpot => l10n.themingVariantTonalSpot,
      M3EColorVariant.vibrant => l10n.themingVariantVibrant,
      M3EColorVariant.fidelity => l10n.themingVariantFidelity,
      M3EColorVariant.expressive => l10n.themingVariantExpressive,
      M3EColorVariant.monochrome => l10n.themingVariantMonochrome,
      M3EColorVariant.neutral => l10n.themingVariantNeutral,
      M3EColorVariant.rainbow => l10n.themingVariantRainbow,
      M3EColorVariant.fruitSalad => l10n.themingVariantFruitSalad,
    };

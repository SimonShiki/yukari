import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';
import 'share_choice_group.dart';

/// How hard the camera is allowed to scan, when this platform has one.
class ScanRateSelector extends StatelessWidget {
  const ScanRateSelector({super.key, required this.controller});

  final QrShareReceiveController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final theme = Theme.of(context);
      final l10n = context.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shareReceiveScanRate, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ShareChoiceGroup(
            semanticLabel: l10n.shareReceiveScanRate,
            labels: [
              l10n.shareReceiveRateRelaxed,
              l10n.shareReceiveRateBalanced,
              l10n.shareReceiveRateTurbo,
            ],
            selectedIndex: ScanPace.values.indexOf(controller.pace.value),
            onSelected: (index) =>
                controller.pace.value = ScanPace.values[index],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.shareReceiveRateHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    },
  );
}

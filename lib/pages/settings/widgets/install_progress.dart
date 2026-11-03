import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// How far an install has come: its download's [progress], from 0 to 1, or
/// null while that is unknown.
class InstallProgress extends StatelessWidget {
  const InstallProgress({super.key, required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            progress == null
                ? context.l10n.settingsInstalling
                : context.l10n.settingsDownloading((progress! * 100).round()),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          M3ELinearWavyProgressIndicator(value: progress),
        ],
      ),
    );
  }
}

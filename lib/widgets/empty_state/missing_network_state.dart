import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'empty_state.dart';

/// The state a network page shows when its network is no longer saved.
///
/// [onGoBack] is what the route and the detail pane each do to leave.
class MissingNetworkState extends StatelessWidget {
  const MissingNetworkState({super.key, required this.onGoBack});

  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: Icons.error_outline,
      title: l10n.networkMissing,
      message: l10n.networkMissingDescription,
      action: FilledButton(onPressed: onGoBack, child: Text(l10n.commonGoBack)),
    );
  }
}

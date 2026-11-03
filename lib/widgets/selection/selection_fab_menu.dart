import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/multi_selection.dart';
import '../../l10n/l10n.dart';

/// The floating action menu a list page wears while it selects: it takes the
/// place of the page's own menu, so the selection's actions are where the
/// create menu was instead of stacked above it.
///
/// Nothing selected leaves both items in the menu but inert, so it never
/// fires on an empty selection. A page with nothing it may delete passes no
/// [onDelete], and the menu offers sharing alone.
class SelectionFabMenu extends StatelessWidget {
  const SelectionFabMenu({
    super.key,
    required this.selection,
    required this.onShare,
    required this.onDelete,
  });

  final MultiSelection selection;

  /// Shares what is selected.
  final VoidCallback onShare;

  /// Deletes what is selected, when the page has anything to delete.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final enabled = selection.count.value > 0;
      final l10n = context.l10n;
      return M3EFabMenu(
        icon: Tooltip(
          message: l10n.selectionActions,
          child: const Icon(Icons.more_vert_rounded),
        ),
        items: [
          M3EFabMenuItem(
            icon: const Icon(Icons.qr_code_2),
            label: l10n.selectionShare,
            onPressed: enabled ? onShare : null,
          ),
          if (onDelete case final delete?)
            M3EFabMenuItem(
              icon: const Icon(Icons.delete_outline),
              label: l10n.selectionDelete,
              onPressed: enabled ? delete : null,
            ),
        ],
      );
    },
  );
}

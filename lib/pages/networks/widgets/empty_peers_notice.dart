import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// The tip shown above the initial-peers list when a network has none: a
/// network without an initial peer may never find the others.
class EmptyPeersNotice extends StatelessWidget {
  const EmptyPeersNotice({
    super.key,
    required this.hasPublicNodes,
    required this.onAddPublic,
    required this.onBrowse,
  });

  /// Whether built-in shared nodes are available to add in one tap.
  final bool hasPublicNodes;
  final VoidCallback onAddPublic;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onContainer = colors.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined, color: onContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.peersEmptyWarning,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onContainer,
                  ),
                ),
              ),
            ],
          ),
          if (!hasPublicNodes)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: Text(
                context.l10n.peersEmptyNoPublic,
                style: theme.textTheme.bodySmall?.copyWith(color: onContainer),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasPublicNodes)
                  M3EButton.icon(
                    style: M3EButtonStyle.filled,
                    icon: const Icon(Icons.public),
                    label: Text(context.l10n.peersEmptyAddPublic),
                    onPressed: onAddPublic,
                  ),
                M3EButton.icon(
                  style: M3EButtonStyle.tonal,
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: Text(context.l10n.peersEmptyBrowse),
                  onPressed: onBrowse,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

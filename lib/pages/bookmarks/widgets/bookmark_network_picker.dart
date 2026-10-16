import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../controllers/bookmarks_actions.dart';
import '../../../l10n/l10n.dart';

/// Asks which network to add the node to; null when dismissed.
///
/// A network that already has the node is disabled and checked.
Future<String?> showBookmarkNetworkPicker(
  BuildContext context, {
  required List<BookmarkNetworkOption> options,
}) => showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.bookmarksAddToNetworkTitle),
    content: SizedBox(
      width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
      child: options.isEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  context.l10n.bookmarksNoNetworks,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.bookmarksNoNetworksDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    leading: const Icon(Icons.hub_outlined),
                    title: Text(option.name),
                    enabled: !option.contains,
                    trailing: option.contains
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: option.contains
                        ? null
                        : () => Navigator.of(context).pop(option.id),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
    ],
  ),
);

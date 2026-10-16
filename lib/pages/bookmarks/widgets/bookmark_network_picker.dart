import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../models/node.dart';
import '../../../signals/networks.dart' as saved_networks;

/// Asks which saved network should receive [bookmark], then adds it there.
Future<void> showNetworkPicker(
  BuildContext context, {
  required Bookmark bookmark,
  required BookmarksController controller,
}) async {
  final networkName = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.bookmarksAddToNetworkTitle),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.5,
        child: SignalBuilder(
          builder: (context) {
            final networks = saved_networks.networks.value.entries.toList();
            if (networks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.bookmarksNoNetworks,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.bookmarksNoNetworksDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: networks.length,
              itemBuilder: (context, index) {
                final entry = networks[index];
                final used = entry.value.nodes.any(
                  (node) => sameNode(node, bookmark.node),
                );
                return ListTile(
                  enabled: !used,
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(entry.value.networkName),
                  trailing: used
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                );
              },
            );
          },
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

  if (networkName != null) controller.addToNetwork(bookmark, networkName);
}

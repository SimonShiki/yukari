import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../share/share_document.dart';
import '../../../widgets/card_surface/card_surface.dart';
import '../../../widgets/metadata_chip/metadata_chip.dart';
import 'share_identity.dart';
import 'share_item_row.dart';

/// What is being shared, in the words the sharing sheet uses: the kind, the
/// network name or peer address, and the peers and secret that travel with it.
class QrShareSummaryCard extends StatelessWidget {
  const QrShareSummaryCard({super.key, required this.documents});

  /// The documents the sender streams, never empty.
  final List<ShareDocument> documents;

  @override
  Widget build(BuildContext context) => documents.length == 1
      ? _single(context, documents.single)
      : _bundle(context);

  /// One share: its identity, its peers and the secret that travels with it.
  Widget _single(BuildContext context, ShareDocument document) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final network = document.kind == ShareKind.network;
    final peer = document.peers.first;
    return CardSurface(
      child: ListTile(
        leading: Icon(
          network ? Icons.hub_outlined : Icons.dns_outlined,
          color: colors.primary,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                shareDisplayTitle(document),
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ShareKindChip(kind: document.kind),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            if (network)
              Text(
                l10n.shareSendPeerCount(document.peers.length) +
                    (document.hasSecret
                        ? ' · ${l10n.shareSendSecretIncluded}'
                        : ''),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (network)
              Text(
                l10n.shareQrSecretWarning,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            if (!network)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final protocol in peer.protocols)
                    MetadataChip.protocol(protocol.name),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// A bundle: how much travels, then one row per document.
  Widget _bundle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                Icon(Icons.layers_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.shareItems(documents.length),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            for (final document in documents)
              ShareItemRow(
                document: document,
                detail: document.kind == ShareKind.network
                    ? l10n.shareSendPeerCount(document.peers.length)
                    : null,
              ),
            if (documents.any((document) => document.hasSecret))
              Text(
                l10n.shareQrSecretWarning,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
          ],
        ),
      ),
    );
  }
}

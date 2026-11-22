import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_receive_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../share/share_document.dart';
import '../../../widgets/card_surface/card_surface.dart';
import 'share_identity.dart';
import 'share_item_row.dart';

/// What arrived, once the transfer completed: the share's identity, its peers
/// and protocols, the action that adds it to the app, and the way to scan
/// another one.
///
/// The page only builds this for a completed transfer, and the network secret
/// is never printed: the row only says one came with the share.
class SharePreviewCard extends StatelessWidget {
  /// Creates the preview card for the completed [shares].
  const SharePreviewCard({
    super.key,
    required this.shares,
    required this.controller,
  });

  /// The shares the transfer produced, never empty.
  final List<ShareDocument> shares;

  /// The receive controller whose save state and actions it drives.
  final QrShareReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final share = shares.length == 1 ? shares.single : null;
    final addLabel = switch (share?.kind) {
      ShareKind.network => l10n.shareReceiveAddNetwork,
      ShareKind.node => l10n.shareReceiveSaveNode,
      null => l10n.shareReceiveAddAll(shares.length),
    };
    final supporting = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return CardSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(
              context,
              share == null ? null : ShareKindChip(kind: share.kind),
            ),
            if (share != null) ...[
              const SizedBox(height: 12),
              Text(
                shareDisplayTitle(share),
                style: theme.textTheme.headlineSmall,
              ),
              if (shareDisplaySubtitle(share) case final address?) ...[
                const SizedBox(height: 4),
                ShareAddressText(address),
              ],
              const SizedBox(height: 12),
              for (final (label, value) in _details(share, l10n))
                _DetailRow(label: label, value: value),
            ] else ...[
              const SizedBox(height: 4),
              Text(l10n.shareItems(shares.length), style: supporting),
              const SizedBox(height: 16),
              for (final item in shares) ...[
                ShareItemRow(document: item),
                const SizedBox(height: 12),
              ],
              if (shares.any((item) => item.hasSecret))
                _DetailRow(
                  label: l10n.sharePreviewSecret,
                  value: l10n.sharePreviewSecretIncluded,
                ),
            ],
            if (shares.any((item) => item.configs != null)) ...[
              const SizedBox(height: 8),
              Text(l10n.shareIncludesConfigs, style: supporting),
            ],
            SizedBox(height: share == null ? 8 : 20),
            _actions(addLabel),
          ],
        ),
      ),
    );
  }

  /// The completed-transfer banner, with what arrived on the right.
  Widget _banner(BuildContext context, Widget? trailing) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.shareReceiveComplete,
            style: theme.textTheme.titleMedium,
          ),
        ),
        ?trailing,
      ],
    );
  }

  /// The card's actions: the one that adds the shares, and the way out.
  Widget _actions(String label) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      final saving = controller.saving.value;
      final saved = controller.saved.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3EButton.icon(
            // A saved share stays disabled: saving it twice would create a
            // second network or report a duplicate node.
            onPressed: saving || saved
                ? null
                : () => unawaited(controller.save()),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(saved ? Icons.check_rounded : Icons.add_rounded),
            label: Text(label),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.reset,
            child: Text(l10n.shareReceiveScanAnother),
          ),
        ],
      );
    },
  );

  /// The labeled facts of [share], in the order the app reads them.
  List<(String, String)> _details(ShareDocument share, AppLocalizations l10n) {
    final protocols = share.peers
        .map((peer) => peer.url.scheme.toUpperCase())
        .toSet()
        .join(' · ');
    return [
      if (share.kind == ShareKind.network)
        (l10n.sharePreviewPeers, '${share.peers.length}'),
      (l10n.sharePreviewProtocols, protocols),
      if (share.hasSecret)
        (l10n.sharePreviewSecret, l10n.sharePreviewSecretIncluded),
    ];
  }
}

/// One label and its value, aligned like a form summary.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

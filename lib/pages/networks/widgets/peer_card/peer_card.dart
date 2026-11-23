import 'package:material_ui/material_ui.dart';
import 'package:yukari_core/models/peer.dart';

import '../../../../widgets/metadata_chip/metadata_chip.dart';
import '../../../../widgets/overflow_text/overflow_text.dart';
import '../../../../models/peer_card_data.dart';

class PeerCard extends StatelessWidget {
  const PeerCard({super.key, required this.data});

  final PeerCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final (
      connectionBackground,
      connectionForeground,
    ) = switch (data.connectionType) {
      PeerConnectionType.local => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      PeerConnectionType.direct => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      PeerConnectionType.relay => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };

    // The minimum preserves alignment while allowing both IP families to wrap.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: textScaler.scale(64)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline: the name, with latency as its status.
                  Row(
                    children: [
                      Flexible(
                        child: OverflowText(
                          data.hostname,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (!data.isSelf && data.latencyMs != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${data.latencyMs} ms',
                          style: textTheme.labelMedium?.copyWith(
                            color: data.getLatencyColor(colors),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Supporting text can wrap when both address families exist.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (data.virtualIpv4 case final ip?)
                        SelectableText(
                          ip,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      if (data.virtualIpv6 case final ip?)
                        SelectableText(
                          ip,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      for (final protocol in data.protocols)
                        MetadataChip.protocol(protocol),
                      for (final tag in data.tags) _PeerTagChip(tag: tag),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Badge(
              backgroundColor: connectionBackground,
              textColor: connectionForeground,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              label: Text(data.connectionStatus, style: textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerTagChip extends StatelessWidget {
  const _PeerTagChip({required this.tag});

  final PeerTag tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = switch (tag.tone) {
      PeerTagTone.positive => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      PeerTagTone.caution => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      PeerTagTone.neutral ||
      null => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    // Tapping also shows the explanation, so it is reachable on touch.
    return Tooltip(
      message: tag.description,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(tag.icon, size: 14, color: foreground),
            Text(
              tag.label,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

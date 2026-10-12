import 'package:material_ui/material_ui.dart';

import 'peer_card_data.dart';

class PeerCard extends StatelessWidget {
  const PeerCard({
    super.key,
    required this.data,
  });

  final PeerCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final textScaler = MediaQuery.textScalerOf(context);

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(12),
      // A fixed two-line height keeps every card, including our own, aligned.
      child: SizedBox(
        height: textScaler.scale(64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          child: Text(
                            data.hostname,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!data.isSelf) ...[
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
                    // Supporting text: one line, most useful first, as
                    // overflow is clipped.
                    SizedBox(
                      height: textScaler.scale(20),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (data.virtualIpv4 case final ip?)
                            Text(
                              ip,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          for (final protocol in data.protocols)
                            Badge(
                              backgroundColor: colors.secondaryContainer,
                              textColor: colors.onSecondaryContainer,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              label: Text(
                                protocol,
                                style: textTheme.labelSmall,
                              ),
                            ),
                          for (final tag in data.tags) _PeerTagChip(tag: tag)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Badge(
                backgroundColor: data.isSelf
                    ? colors.tertiaryContainer
                    : colors.primaryContainer,
                textColor: data.isSelf
                    ? colors.onTertiaryContainer
                    : colors.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                label: Text(
                  data.connectionStatus,
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
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

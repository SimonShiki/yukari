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

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Identity icon, security icon, and hostname
                  Row(
                    children: [
                      Icon(
                        data.identityIcon,
                        size: 20,
                        color: colors.primary,
                      ),
                      if (data.secureIcon != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          data.secureIcon,
                          size: 18,
                          color: data.secureIconColor ?? colors.tertiary,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.hostname,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ID and protocol chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        data.id,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (data.protocols.isNotEmpty)
                        ...data.protocols.map(
                          (protocol) => Badge(
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
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Latency and connection status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.latencyMs}ms',
                  style: textTheme.bodyMedium?.copyWith(
                    color: data.getLatencyColor(colors),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Badge(
                  backgroundColor: colors.primaryContainer,
                  textColor: colors.onPrimaryContainer,
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
          ],
        ),
      ),
    );
  }
}

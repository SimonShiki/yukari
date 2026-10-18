part of 'magic_dns_card.dart';

/// A copyable block of commands.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.label, required this.lines});

  final String label;
  final List<String> lines;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    showAppSnackBar(context, context.l10n.magicDnsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSecondaryContainer,
          ),
        ),
        Material(
          color: colors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    lines.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.magicDnsCopy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

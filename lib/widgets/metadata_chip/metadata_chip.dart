import 'package:material_ui/material_ui.dart';

/// How a [MetadataChip] is toned.
enum MetadataChipTone {
  /// A protocol such as `TCP` or `QUIC`: tonal, to read as a property of the
  /// node rather than a status.
  protocol,

  /// A free-form tag such as `#overseas`: neutral, because the user made it.
  tag,
}

/// A small read-only label for node metadata, shared by the peer rows in the
/// network editor and the bookmark rows.
///
/// Both places used to draw their own `Badge`: the peer row took Material's
/// default badge colors, which are the *error* tokens, so a protocol looked
/// like a failure. One widget keeps the two lists consistent.
class MetadataChip extends StatelessWidget {
  const MetadataChip(this.label, {super.key, this.tone = MetadataChipTone.tag});

  /// A protocol badge; [protocol] is upper-cased, e.g. `tcp` becomes `TCP`.
  MetadataChip.protocol(String protocol, {Key? key})
    : this(protocol.toUpperCase(), key: key, tone: MetadataChipTone.protocol);

  final String label;
  final MetadataChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      // Tonal: the same container pair the app uses for secondary metadata.
      MetadataChipTone.protocol => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      // Neutral: tags are user data, so they stay quiet.
      MetadataChipTone.tag => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    final theme = Theme.of(context);
    return Badge(
      backgroundColor: background,
      textColor: foreground,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      label: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

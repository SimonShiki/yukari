import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../share/share_document.dart';
import '../../../widgets/metadata_chip/metadata_chip.dart';

/// A chip naming what a share describes, shared by the sender and receiver.
class ShareKindChip extends StatelessWidget {
  const ShareKindChip({super.key, required this.kind});

  final ShareKind kind;

  @override
  Widget build(BuildContext context) => MetadataChip(switch (kind) {
    ShareKind.network => context.l10n.shareKindNetwork,
    ShareKind.node => context.l10n.shareKindNode,
  }, tone: MetadataChipTone.protocol);
}

/// The title a share shows: its name, or the single peer's address when it has
/// none.
String shareDisplayTitle(ShareDocument document) =>
    document.name ?? document.peers.first.address;

/// The address a share shows under its title: a named node share keeps the
/// address it points at, and every other share has nothing left to add.
String? shareDisplaySubtitle(ShareDocument document) =>
    document.kind == ShareKind.node && document.name != null
    ? document.peers.first.address
    : null;

/// The address line a share shows under a named node's title.
class ShareAddressText extends StatelessWidget {
  const ShareAddressText(this.address, {super.key, this.style});

  /// The `host:port` a [ShareDocument] peer names.
  final String address;

  /// The text style it inherits from; cards use the secondary body style by
  /// default, and a list row passes its smaller one.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      address,
      style: (style ?? theme.textTheme.bodyMedium)?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

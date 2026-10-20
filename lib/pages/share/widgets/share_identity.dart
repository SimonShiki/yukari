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

/// The title a share shows: the network's name, or the single peer's address.
String shareDisplayTitle(ShareDocument document) =>
    document.kind == ShareKind.network
    ? (document.name ?? '')
    : document.peers.first.address;

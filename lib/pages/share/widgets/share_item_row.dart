import 'package:material_ui/material_ui.dart';

import '../../../share/share_document.dart';
import 'share_identity.dart';

/// One share of a bundle on one line: what it is, and one more fact about it.
class ShareItemRow extends StatelessWidget {
  const ShareItemRow({super.key, required this.document, this.detail});

  /// The share this row describes.
  final ShareDocument document;

  /// A supporting line under the title, such as the share's peer count; a named
  /// node's address takes its place when no detail is given.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final detail = this.detail;
    final address = detail == null ? shareDisplaySubtitle(document) : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            document.kind == ShareKind.network
                ? Icons.hub_outlined
                : Icons.dns_outlined,
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                shareDisplayTitle(document),
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
              if (detail != null)
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              if (address != null)
                ShareAddressText(address, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';

/// The ways [bookmark] can be shared or exported.
///
/// Every row closes the sheet before running its action, so the outcome is not
/// reported behind an open sheet.
Future<void> showBookmarkShareSheet(
  BuildContext context, {
  required Bookmark bookmark,
  required VoidCallback onShareOverNetwork,
  required VoidCallback onShowQr,
  required VoidCallback onCopyAddress,
  required VoidCallback onExportJson,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => M3EBottomSheet(
    title: Text(
      context.l10n.bookmarksShareTitle(bookmark.displayName),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _channel(
          context,
          icon: Icons.share_outlined,
          title: context.l10n.bookmarksShareOverNetwork,
          subtitle: context.l10n.bookmarksShareOverNetworkSubtitle,
          onTap: onShareOverNetwork,
        ),
        _channel(
          context,
          icon: Icons.qr_code_2,
          title: context.l10n.bookmarksShowQr,
          subtitle: context.l10n.bookmarksShowQrSubtitle,
          onTap: onShowQr,
        ),
        _channel(
          context,
          icon: Icons.content_copy,
          title: context.l10n.bookmarksCopyAddress,
          subtitle: bookmark.address,
          onTap: onCopyAddress,
        ),
        _channel(
          context,
          icon: Icons.file_download_outlined,
          title: context.l10n.bookmarksExportJson,
          subtitle: context.l10n.bookmarksExportJsonSubtitle,
          onTap: onExportJson,
        ),
      ],
    ),
  ),
);

Widget _channel(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) => InkWell(
  onTap: () {
    Navigator.of(context).pop();
    onTap();
  },
  child: M3EListItem(
    leading: Icon(icon),
    headline: Text(title),
    supportingText: Text(subtitle),
  ),
);

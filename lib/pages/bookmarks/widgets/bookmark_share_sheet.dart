import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';

/// Shows the ways [bookmark] can leave this device: over a connected network,
/// as a QR code, as copied text, or as a JSON file.
Future<void> showBookmarkShareSheet(
  BuildContext context, {
  required Bookmark bookmark,
  required BookmarksController controller,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    Widget action({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onPressed,
    }) => InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onPressed();
      },
      child: M3EListItem(
        leading: M3EContainer(
          Shapes.c4SidedCookie,
          width: 40,
          height: 40,
          color: colors.primaryContainer,
          child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
        ),
        headline: Text(title),
        supportingText: Text(subtitle),
      ),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              context.l10n.bookmarksShareTitle(bookmark.displayName),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          action(
            icon: Icons.wifi_tethering,
            title: context.l10n.bookmarksShareOverNetwork,
            subtitle: context.l10n.bookmarksShareOverNetworkSubtitle,
            onPressed: () => controller.shareOverNetwork(bookmark),
          ),
          action(
            icon: Icons.qr_code_2,
            title: context.l10n.bookmarksShowQr,
            subtitle: context.l10n.bookmarksShowQrSubtitle,
            onPressed: () => controller.showQrCode(bookmark),
          ),
          action(
            icon: Icons.content_copy,
            title: context.l10n.bookmarksCopyAddress,
            subtitle: bookmark.address,
            onPressed: () => controller.copyAddress(bookmark),
          ),
          action(
            icon: Icons.file_download_outlined,
            title: context.l10n.bookmarksExportJson,
            subtitle: context.l10n.bookmarksExportJsonSubtitle,
            onPressed: () => controller.exportToFile([bookmark]),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  },
);

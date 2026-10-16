import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// The bookmarks page's action menu: add, import, and scan a QR code.
class BookmarksFabMenu extends StatelessWidget {
  const BookmarksFabMenu({
    super.key,
    required this.onAdd,
    required this.onImport,
    required this.onScan,
  });

  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return M3EFabMenu(
      items: [
        M3EFabMenuItem(
          icon: const Icon(Icons.add),
          label: l10n.bookmarksAdd,
          onPressed: onAdd,
        ),
        M3EFabMenuItem(
          icon: const Icon(Icons.file_upload_outlined),
          label: l10n.bookmarksImportFile,
          onPressed: onImport,
        ),
        M3EFabMenuItem(
          icon: const Icon(Icons.qr_code_scanner),
          label: l10n.bookmarksScanQr,
          onPressed: onScan,
        ),
      ],
    );
  }
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

class NetworkCreateMenu extends StatelessWidget {
  const NetworkCreateMenu({
    super.key,
    required this.onCreate,
    required this.onImport,
    required this.onScan,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => M3EFabMenu(
    icon: Icon(Icons.add_rounded, semanticLabel: context.l10n.networkAdd),
    closeIcon: Icon(
      Icons.close_rounded,
      semanticLabel: context.l10n.networkCloseMenu,
    ),
    items: [
      M3EFabMenuItem(
        icon: const Icon(Icons.edit_outlined),
        label: context.l10n.networkCreateManually,
        onPressed: onCreate,
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.file_open_outlined),
        label: context.l10n.networkImportFile,
        onPressed: onImport,
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: context.l10n.networkScanQr,
        onPressed: onScan,
      ),
    ],
  );
}

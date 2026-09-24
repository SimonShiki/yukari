import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

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
    icon: const Icon(Icons.add_rounded, semanticLabel: 'Add network'),
    closeIcon: const Icon(
      Icons.close_rounded,
      semanticLabel: 'Close network menu',
    ),
    items: [
      M3EFabMenuItem(
        icon: const Icon(Icons.edit_outlined),
        label: 'Create manually',
        onPressed: onCreate,
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.file_open_outlined),
        label: 'Import from file',
        onPressed: onImport,
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: 'Scan QR code',
        onPressed: onScan,
      ),
    ],
  );
}

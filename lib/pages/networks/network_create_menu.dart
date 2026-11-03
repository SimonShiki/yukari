import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/network_page_controller.dart';
import '../../l10n/l10n.dart';

/// The networks page's create menu: create a network by hand, import one from
/// a TOML config, or scan a QR code to receive one.
class NetworkCreateMenu extends StatelessWidget {
  const NetworkCreateMenu({super.key, required this.controller});

  final NetworkPageController controller;

  @override
  Widget build(BuildContext context) => M3EFabMenu(
    icon: Tooltip(
      message: context.l10n.networkAdd,
      child: const Icon(Icons.add_rounded),
    ),
    closeIcon: Tooltip(
      message: context.l10n.networkCloseMenu,
      child: const Icon(Icons.close_rounded),
    ),
    items: [
      M3EFabMenuItem(
        icon: const Icon(Icons.edit_outlined),
        label: context.l10n.networkCreateManually,
        onPressed: controller.createManually,
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.file_open_outlined),
        label: context.l10n.networkImportFile,
        onPressed: () => unawaited(controller.importFromFile()),
      ),
      M3EFabMenuItem(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: context.l10n.networkScanQr,
        onPressed: controller.receiveByQr,
      ),
    ],
  );
}

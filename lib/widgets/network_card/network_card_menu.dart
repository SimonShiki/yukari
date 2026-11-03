import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../context_menu/m3e_context_menu.dart';

class NetworkCardMenu extends StatelessWidget {
  const NetworkCardMenu({
    super.key,
    required this.name,
    required this.running,
    required this.onEdit,
    required this.onShare,
    required this.onExport,
    required this.onLog,
    required this.onDelete,
    required this.builder,
    this.busy = false,
  });

  final String name;
  final bool running;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onExport;
  final VoidCallback onLog;
  final VoidCallback onDelete;
  final Widget Function(BuildContext, Widget) builder;

  @override
  Widget build(BuildContext context) => M3EContextMenu(
    tooltip: context.l10n.cardMoreOptions(name),
    actions: [
      M3EMenuAction(
        icon: Icons.edit_outlined,
        label: context.l10n.commonEdit,
        onPressed: running || busy ? null : onEdit,
      ),
      M3EMenuAction(
        icon: Icons.qr_code_2_rounded,
        label: context.l10n.cardShareQr,
        onPressed: onShare,
      ),
      M3EMenuAction(
        icon: Icons.file_download_outlined,
        label: context.l10n.cardExport,
        onPressed: onExport,
      ),
      M3EMenuAction(
        icon: Icons.article_outlined,
        label: context.l10n.cardLog,
        onPressed: running ? onLog : null,
      ),
      M3EMenuAction(
        icon: Icons.delete_outline,
        label: context.l10n.commonDelete,
        onPressed: busy ? null : onDelete,
        destructive: true,
      ),
    ],
    builder: builder,
  );
}

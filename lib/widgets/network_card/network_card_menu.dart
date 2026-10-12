import 'package:material_ui/material_ui.dart';

import '../context_menu/m3e_context_menu.dart';

class NetworkCardMenu extends StatelessWidget {
  const NetworkCardMenu({
    super.key,
    required this.name,
    required this.running,
    required this.onEdit,
    required this.onLog,
    required this.onDelete,
    required this.builder,
    this.busy = false,
  });

  final String name;
  final bool running;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onLog;
  final VoidCallback onDelete;
  final Widget Function(BuildContext, Widget) builder;

  @override
  Widget build(BuildContext context) => M3EContextMenu(
    tooltip: 'More options for $name',
    actions: [
      M3EMenuAction(
        icon: Icons.edit_outlined,
        label: 'Edit',
        onPressed: running || busy ? null : onEdit,
      ),
      M3EMenuAction(
        icon: Icons.article_outlined,
        label: 'Log',
        onPressed: running ? onLog : null,
      ),
      M3EMenuAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        onPressed: busy ? null : onDelete,
        destructive: true,
      ),
    ],
    builder: builder,
  );
}

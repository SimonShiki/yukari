import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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
  Widget build(BuildContext context) => MenuAnchor(
    consumeOutsideTap: true,
    menuChildren: [
      MenuItemButton(
        onPressed: running || busy ? null : onEdit,
        leadingIcon: const Icon(Icons.edit_outlined),
        child: const Text('Edit'),
      ),
      MenuItemButton(
        onPressed: running ? onLog : null,
        leadingIcon: const Icon(Icons.article_outlined),
        child: const Text('Log'),
      ),
      MenuItemButton(
        onPressed: busy ? null : onDelete,
        style: MenuItemButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          iconColor: Theme.of(context).colorScheme.error,
        ),
        leadingIcon: const Icon(Icons.delete_outline),
        child: const Text('Delete'),
      ),
    ],
    builder: (context, controller, child) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): controller.open,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true):
            controller.open,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        child: builder(
          context,
          SizedBox(),
        ),
      ),
    ),
  );
}

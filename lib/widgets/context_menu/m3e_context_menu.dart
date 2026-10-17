import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'm3e_menu_anchor.dart';

export 'm3e_menu_panel.dart' show M3EMenuAction;

/// An M3 Expressive menu for [builder]'s region, opened by its overflow
/// button, a secondary click, or the context menu keyboard shortcuts.
class M3EContextMenu extends StatefulWidget {
  const M3EContextMenu({
    super.key,
    required this.actions,
    required this.tooltip,
    required this.builder,
  });

  final List<M3EMenuAction> actions;

  /// Tooltip of the overflow button.
  final String tooltip;
  final Widget Function(BuildContext context, Widget menuButton) builder;

  @override
  State<M3EContextMenu> createState() => _M3EContextMenuState();
}

class _M3EContextMenuState extends State<M3EContextMenu> {
  final _buttonKey = GlobalKey();

  void _openFromButton(M3EMenuAnchorController menu) {
    if (menu.isOpen) return menu.close();
    final button = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    menu.openAt(button.localToGlobal(Offset.zero) & button.size);
  }

  @override
  Widget build(BuildContext context) => M3EMenuAnchor(
    actions: widget.actions,
    childBuilder: (context, menu) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
            _openFromButton(menu),
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
            _openFromButton(menu),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) =>
            menu.openAt(details.globalPosition & Size.zero),
        child: widget.builder(
          context,
          IconButton(
            key: _buttonKey,
            tooltip: widget.tooltip,
            onPressed: () => _openFromButton(menu),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ),
      ),
    ),
  );
}

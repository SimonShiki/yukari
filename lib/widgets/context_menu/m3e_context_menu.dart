import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'm3e_menu_layout.dart';
import 'm3e_menu_panel.dart';

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

SpringDescription _spring(M3EMotion motion) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: motion.stiffness,
      ratio: motion.damping,
    );

class _M3EContextMenuState extends State<M3EContextMenu>
    with SingleTickerProviderStateMixin {
  final _menu = MenuController();
  final _anchorKey = GlobalKey();
  final _buttonKey = GlobalKey();
  late final _progress = AnimationController.unbounded(vsync: this);

  /// What the menu opens from, relative to the anchor. Empty for a pointer.
  Rect _origin = Rect.zero;
  bool _visible = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Rect _local(Rect global) {
    final anchor = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    return Rect.fromPoints(
      anchor.globalToLocal(global.topLeft),
      anchor.globalToLocal(global.bottomRight),
    );
  }

  void _openAt(Rect origin) {
    _origin = origin;
    _menu.open();
  }

  void _openFromButton() {
    if (_visible) return _menu.close();
    final button = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    _openAt(_local(button.localToGlobal(Offset.zero) & button.size));
  }

  TickerFuture _animate(double target, M3EMotion motion) =>
      _progress.animateWith(
        SpringSimulation(
          _spring(motion),
          _progress.value,
          target,
          _progress.velocity,
          snapToEnd: true,
        ),
      );

  void _handleOpen(Offset? _, VoidCallback showOverlay) {
    showOverlay();
    if (_visible) return;
    setState(() => _visible = true);
    _animate(1, M3EMotion.standardOverflow);
  }

  void _handleClose(VoidCallback hideOverlay) {
    if (!_visible) return;
    setState(() => _visible = false);
    _animate(0, M3EMotion.standardEffectsFast).whenCompleteOrCancel(() {
      if (!_visible) hideOverlay();
    });
  }

  Widget _buildMenu(BuildContext context, RawMenuOverlayInfo info) {
    final origin = _origin.shift(info.anchorRect.topLeft);
    // Menus from a button align to its end edge; from a pointer, to its start.
    final alignment = origin.isEmpty ? Alignment.topLeft : Alignment.topRight;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: M3EMenuLayout(origin, MediaQuery.paddingOf(context)),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          onTapOutside: (_) => _menu.close(),
          child: IgnorePointer(
            ignoring: !_visible,
            child: ExcludeFocus(
              excluding: !_visible,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) => Opacity(
                  opacity: _progress.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.72 + 0.28 * _progress.value,
                    alignment: alignment,
                    child: child,
                  ),
                ),
                // Hosting focus above the anchor keeps the anchor's own focus
                // state, and so its subtree, unchanged while the menu is open.
                child: FocusScope(
                  parentNode: FocusScope.of(this.context),
                  autofocus: true,
                  child: M3EMenuPanel(
                    actions: widget.actions,
                    onSelected: (action) {
                      _menu.close();
                      action();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: _menu,
    onOpenRequested: _handleOpen,
    onCloseRequested: _handleClose,
    overlayBuilder: _buildMenu,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): _openFromButton,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true):
            _openFromButton,
      },
      child: GestureDetector(
        key: _anchorKey,
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) =>
            _openAt(_local(details.globalPosition & Size.zero)),
        child: widget.builder(
          context,
          IconButton(
            key: _buttonKey,
            tooltip: widget.tooltip,
            onPressed: _openFromButton,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ),
      ),
    ),
  );
}

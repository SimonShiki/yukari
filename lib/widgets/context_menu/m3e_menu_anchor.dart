import 'package:flutter/physics.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'm3e_menu_layout.dart';
import 'm3e_menu_panel.dart';

export 'm3e_menu_panel.dart' show M3EMenuAction;

/// Opens and closes the menu of one [M3EMenuAnchor].
class M3EMenuAnchorController {
  M3EMenuAnchorController._(this._anchor);

  final _M3EMenuAnchorState _anchor;

  /// Whether the menu is currently showing.
  bool get isOpen => _anchor._visible;

  /// Shows the menu below [globalOrigin], flipping above it when it would not
  /// fit. An empty rect anchors the menu's top-left at its top-left.
  void openAt(Rect globalOrigin) => _anchor._open(globalOrigin);

  /// Plays the exit animation and hides the menu.
  void close() => _anchor._close();
}

/// The shared machinery of an M3 Expressive menu: builds [actions] in an
/// overlay anchored to its child, animates it in and out and runs the pressed
/// action.
///
/// Callers only decide what opens the menu and from which rect, through the
/// [M3EMenuAnchorController] handed to [childBuilder].
class M3EMenuAnchor extends StatefulWidget {
  const M3EMenuAnchor({
    super.key,
    required this.actions,
    required this.childBuilder,
  });

  final List<M3EMenuAction> actions;

  /// Builds the trigger, which is also the region the menu is laid out from.
  final Widget Function(
    BuildContext context,
    M3EMenuAnchorController controller,
  ) childBuilder;

  @override
  State<M3EMenuAnchor> createState() => _M3EMenuAnchorState();
}

class _M3EMenuAnchorState extends State<M3EMenuAnchor>
    with SingleTickerProviderStateMixin {
  final _menu = MenuController();
  final _anchorKey = GlobalKey();
  late final _progress = AnimationController.unbounded(vsync: this);
  late final M3EMenuAnchorController _controller;

  /// What the menu opens from, relative to the anchor. Empty for a pointer.
  Rect _origin = Rect.zero;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = M3EMenuAnchorController._(this);
  }

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

  void _open(Rect globalOrigin) {
    _origin = _local(globalOrigin);
    _menu.open();
  }

  void _close() => _menu.close();

  TickerFuture _animate(double target, M3EMotion motion) =>
      _progress.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: motion.stiffness,
            ratio: motion.damping,
          ),
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
    // Menus from a region align to its end edge; from a pointer, to its start.
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
                      action.onPressed?.call();
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
    child: GestureDetector(
      key: _anchorKey,
      behavior: HitTestBehavior.opaque,
      child: widget.childBuilder(context, _controller),
    ),
  );
}

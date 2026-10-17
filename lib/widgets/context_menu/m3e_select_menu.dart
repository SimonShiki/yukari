import 'package:material_ui/material_ui.dart';

import 'm3e_menu_anchor.dart';

/// A menu opened by tapping [child] at the tapped position, listing [options]
/// as one-of selection entries.
///
/// The entry whose value equals [value] is highlighted and checkmarked. The
/// widget is stateful only for the tap position: bind [value] to a signal with
/// a [SignalBuilder] so a new choice rebuilds the trigger.
class M3ESelectMenu<T> extends StatefulWidget {
  const M3ESelectMenu({
    super.key,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.onSelected,
    required this.child,
  });

  final List<T> options;

  /// The current choice, rendered as the selected menu entry.
  final T value;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  /// The trigger: its whole area opens the menu.
  final Widget child;

  @override
  State<M3ESelectMenu<T>> createState() => _M3ESelectMenuState<T>();
}

class _M3ESelectMenuState<T> extends State<M3ESelectMenu<T>> {
  /// Where the trigger was last hit, or null for a keyboard activation.
  Offset? _tapPosition;
  final _triggerKey = GlobalKey();

  /// Opens at the pointer, or under the whole trigger row when the activation
  /// came from the keyboard and there is no pointer position.
  void _open(M3EMenuAnchorController menu) {
    final tap = _tapPosition;
    _tapPosition = null;
    if (tap != null) return menu.openAt(tap & Size.zero);
    final trigger =
        _triggerKey.currentContext!.findRenderObject()! as RenderBox;
    menu.openAt(trigger.localToGlobal(Offset.zero) & trigger.size);
  }

  @override
  Widget build(BuildContext context) => M3EMenuAnchor(
    actions: [
      for (final option in widget.options)
        M3EMenuAction(
          label: widget.labelOf(option),
          selected: option == widget.value,
          onPressed: () => widget.onSelected(option),
        ),
    ],
    childBuilder: (context, menu) => Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: _triggerKey,
        // The whole trigger is one tap target; the menu opens where it was hit.
        onTapDown: (details) => _tapPosition = details.globalPosition,
        // A drag away from the trigger cancels the tap; a later keyboard
        // activation must not reuse that stale pointer position.
        onTapCancel: () => _tapPosition = null,
        onTap: () => _open(menu),
        child: widget.child,
      ),
    ),
  );
}

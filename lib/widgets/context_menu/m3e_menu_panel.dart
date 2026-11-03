import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// One entry of an M3 Expressive menu.
///
/// Action menus pass a [icon] for each entry. Selection menus (dropdowns) pass
/// no icon: the selected entry then shows a checkmark in the leading slot.
class M3EMenuAction {
  const M3EMenuAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.destructive = false,
    this.selected = false,
  });

  final String label;

  /// The leading icon, or null for a selection entry, which shows a checkmark
  /// at the same spot when it is [selected].
  final IconData? icon;

  /// Disables the entry when null.
  final VoidCallback? onPressed;

  /// Paints the entry in the error color, as for a destructive action.
  final bool destructive;

  /// Highlights this entry and, when it has no [icon], marks it with a
  /// leading checkmark.
  final bool selected;
}

/// The container and segmented items of an M3 Expressive menu.
///
/// Items have no background of their own: the panel is one elevated surface
/// and only a selected or hovered item paints a shape over it.
class M3EMenuPanel extends StatelessWidget {
  const M3EMenuPanel({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<M3EMenuAction> actions;
  final ValueChanged<M3EMenuAction> onSelected;

  Widget _buildItem(BuildContext context, M3EMenuAction action) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (action) {
      M3EMenuAction(onPressed: null) => colors.onSurface.withValues(
        alpha: 0.38,
      ),
      M3EMenuAction(selected: true) => colors.onSecondaryContainer,
      M3EMenuAction(destructive: true) => colors.error,
      _ => colors.onSurface,
    };
    final leading = action.icon == null
        ? (action.selected
              ? Icon(Icons.check_rounded, size: 20, color: color)
              : null)
        : Icon(action.icon, size: 20, color: color);
    return Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 12)],
        Flexible(
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 280),
      child: IntrinsicWidth(
        child: Material(
          color: colors.surfaceContainer,
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          // Menus scroll when they are taller than the space they open into.
          child: SingleChildScrollView(
            child: M3ESegmentedColumn(
              // The panel is the only surface: items stay flat until selected.
              decoration: M3ESegmentedListDecoration(
                // M3 Expressive menu tokens: a 4dp item shape, a 12dp selected
                // item shape, all inset 4dp in the 16dp panel.
                outerRadius: 4,
                innerRadius: 4,
                gap: 2,
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: Colors.transparent,
                disabledColor: Colors.transparent,
                // No custom hover color: the theme's translucent state layer
                // tints whatever the item paints, so a selected item stays
                // selected instead of turning the unselected hover gray.
                focusedColor: colors.surfaceContainerHighest,
                selectedColor: colors.secondaryContainer,
                selectedRadius: 12,
                haptic: M3EHapticFeedback.light,
              ),
              isSelected: (index) => actions[index].selected,
              isEnabled: (index) => actions[index].onPressed != null,
              onTap: (index) => onSelected(actions[index]),
              children: [
                for (final action in actions) _buildItem(context, action),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

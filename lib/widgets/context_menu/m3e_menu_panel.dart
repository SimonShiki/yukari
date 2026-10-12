import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

class M3EMenuAction {
  const M3EMenuAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// Disables the item when null.
  final VoidCallback? onPressed;
  final bool destructive;
}

/// The container and segmented items of an M3 Expressive menu.
class M3EMenuPanel extends StatelessWidget {
  const M3EMenuPanel({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<M3EMenuAction> actions;
  final ValueChanged<VoidCallback> onSelected;

  Widget _buildItem(BuildContext context, M3EMenuAction action) {
    final colors = Theme.of(context).colorScheme;
    final color = action.onPressed == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : (action.destructive ? colors.error : colors.onSurface);
    return Row(
      children: [
        Icon(action.icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          action.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
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
          child: M3ESegmentedColumn(
            margin: const EdgeInsets.all(4),
            outerRadius: 12,
            innerRadius: 4,
            color: colors.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            haptic: M3EHapticFeedback.light,
            isEnabled: (i) => actions[i].onPressed != null,
            onTap: (i) => onSelected(actions[i].onPressed!),
            children: [
              for (final action in actions) _buildItem(context, action),
            ],
          ),
        ),
      ),
    );
  }
}

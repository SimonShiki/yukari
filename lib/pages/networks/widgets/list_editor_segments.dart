import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// An entry of an editable list, shown as one segment of its section.
class ListEntrySegment extends StatelessWidget {
  const ListEntrySegment({
    super.key,
    required this.icon,
    required this.shape,
    required this.color,
    required this.onColor,
    required this.headline,
    required this.supporting,
    required this.deleteTooltip,
    required this.onDelete,
    this.actions = const [],
  });

  final IconData icon;
  final Shapes shape;
  final Color color;
  final Color onColor;
  final String headline;
  final Widget supporting;
  final String deleteTooltip;
  final VoidCallback onDelete;

  /// Extra buttons shown before the delete button.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => M3EListItem(
    leading: M3EContainer(
      shape,
      width: 40,
      height: 40,
      color: color,
      child: Icon(icon, size: 20, color: onColor),
    ),
    headline: Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis),
    supportingText: supporting,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...actions,
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: deleteTooltip,
          onPressed: onDelete,
        ),
      ],
    ),
  );
}

/// Placeholder segment for a list without entries.
class EmptyListSegment extends StatelessWidget {
  const EmptyListSegment({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return M3EListItem(
      leading: M3EContainer(
        Shapes.c4SidedCookie,
        width: 40,
        height: 40,
        color: colors.surfaceContainerHighest,
        child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
      ),
      headline: Text(text),
      headlineStyle: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: colors.onSurfaceVariant),
    );
  }
}

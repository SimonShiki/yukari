import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// One dashboard tile: a shaped icon and title, an optional trailing action,
/// and the card's value below them.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.shape,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final Shapes shape;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// The height every card header reserves for its trailing action.
  static const double trailingSlot = 32;

  /// The gap between a card's value and its supporting line, which the value
  /// and its [DashboardSkeleton] must share to keep one card height.
  static const double lineGap = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                spacing: 10,
                children: [
                  M3EContainer(
                    shape,
                    width: 32,
                    height: 32,
                    color: theme.colorScheme.secondaryContainer,
                    child: Icon(
                      icon,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.emphasizedTextTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: trailingSlot, child: trailing),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The small icon action a dashboard card shows in its header.
class DashboardAction extends StatelessWidget {
  const DashboardAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
  );
}

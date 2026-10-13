import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'dashboard_skeleton.dart';

/// A tile of the home dashboard: an [icon] in an expressive [shape], a
/// [title], and the tile's content.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.shape = Shapes.c4SidedCookie,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Shapes shape;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Row(
                spacing: 10,
                children: [
                  M3EContainer(
                    shape,
                    width: 32,
                    height: 32,
                    color: colors.secondaryContainer,
                    child: Icon(
                      icon,
                      size: 18,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.emphasizedTextTheme.titleSmall,
                    ),
                  ),
                  // As tall as the icon, so that every header lines up.
                  SizedBox(height: 32, child: trailing),
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

/// The content of a [DashboardCard]: one line of [value], and one of what
/// it means. Fixed to these two lines so that every card is as tall as its
/// neighbours, with [tooltip] for what does not fit.
class DashboardValue extends StatelessWidget {
  const DashboardValue({
    super.key,
    required this.value,
    required this.supporting,
    this.tooltip,
    this.selectable = false,
    this.supportingIcon,
    this.supportingColor,
  }) : loading = false;

  /// A skeleton of the two lines, until the card's data is in.
  const DashboardValue.loading({super.key})
    : value = '',
      supporting = '',
      tooltip = null,
      selectable = false,
      supportingIcon = null,
      supportingColor = null,
      loading = true;

  final String value;
  final String supporting;
  final String? tooltip;

  /// Lets the user select [value] to copy it, as for addresses.
  final bool selectable;
  final bool loading;

  /// Marks [supporting] as a status, such as how well P2P works. Both the
  /// icon and the text wear [supportingColor], so that the status never
  /// rests on color alone.
  final IconData? supportingIcon;
  final Color? supportingColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.emphasizedTextTheme.titleLarge;
    final supportingColor =
        this.supportingColor ?? theme.colorScheme.onSurfaceVariant;
    final supportingStyle = theme.textTheme.bodySmall?.copyWith(
      color: supportingColor,
    );
    final Widget content = loading
        ? DashboardSkeleton(valueStyle: style, supportingStyle: supportingStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              selectable
                  ? SelectableText(value, style: style, maxLines: 1)
                  : Text(
                      value,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              Row(
                spacing: 4,
                children: [
                  if (supportingIcon case final icon?)
                    Icon(icon, size: 14, color: supportingColor),
                  Flexible(
                    child: Text(
                      supporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: supportingStyle,
                    ),
                  ),
                ],
              ),
            ],
          );
    return AnimatedSwitcher(
      duration: Durations.medium2,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Easing.emphasizedAccelerate,
      // The skeleton is as tall as the text, so they overlap in place.
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(loading),
        child: switch (tooltip) {
          final message? => Tooltip(message: message, child: content),
          null => content,
        },
      ),
    );
  }
}

/// A compact icon button for a [DashboardCard]'s header.
class DashboardAction extends StatelessWidget {
  const DashboardAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 18,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    icon: Icon(icon),
  );
}

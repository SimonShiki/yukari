import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'dashboard_card.dart';

/// The pulsing placeholder for a card's value and supporting lines.
///
/// Each bar takes its height from an invisible text line of the style it
/// replaces, so the card keeps its height when the data arrives. The first bar
/// spans the card, the second is shorter, so the pair reads as two lines of
/// text.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.homeLoading,
      child: Column(
        // Stretch, so every bar spans the card instead of shrinking to the
        // width of the invisible space that sizes it.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DashboardCard.lineGap,
        children: [
          _SkeletonLine(style: theme.emphasizedTextTheme.titleLarge),
          _SkeletonLine(style: theme.textTheme.bodySmall, fraction: 0.6),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatefulWidget {
  const _SkeletonLine({required this.style, this.fraction = 1});

  final TextStyle? style;

  /// The share of the card width the bar spans.
  final double fraction;

  @override
  State<_SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<_SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Durations.medium4,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.6,
    end: 1,
  ).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // A static bar, as bright as the pulse ever gets.
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant
        .withValues(alpha: 0.25);
    return Stack(
      children: [
        // Invisible, but it sizes the bar to the line it replaces.
        Opacity(opacity: 0, child: Text(' ', style: widget.style)),
        Positioned.fill(
          child: FadeTransition(
            opacity: _opacity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widget.fraction,
                heightFactor: 0.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cross-fades the skeleton and the loaded value, so nothing reflows.
class DashboardValueSwitcher extends StatelessWidget {
  const DashboardValueSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Durations.medium2,
    switchInCurve: Easing.emphasizedDecelerate,
    switchOutCurve: Easing.emphasizedAccelerate,
    // The default builder centers its child after shrinking it to its widest
    // line, so the card's text reads as centered. The card hands this subtree
    // a tight width; pass it through so the value lines start at the content
    // edge and the skeleton bars span the card.
    layoutBuilder: (currentChild, previousChildren) => Stack(
      fit: StackFit.passthrough,
      alignment: AlignmentDirectional.topStart,
      children: [...previousChildren, ?currentChild],
    ),
    child: child,
  );
}

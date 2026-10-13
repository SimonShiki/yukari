import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Pulsing bars in place of a [DashboardValue]'s two lines while its data
/// loads, each as tall as the line of text it stands for so that nothing
/// moves when the text arrives.
class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({
    super.key,
    required this.valueStyle,
    required this.supportingStyle,
  });

  final TextStyle? valueStyle;
  final TextStyle? supportingStyle;

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: Durations.extralong4,
    lowerBound: 0.4,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.homeLoading,
    child: FadeTransition(
      opacity: CurvedAnimation(parent: _pulse, curve: Easing.standard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          _Bar(style: widget.valueStyle, widthFactor: 0.6),
          _Bar(style: widget.supportingStyle, widthFactor: 0.85),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.style, required this.widthFactor});

  final TextStyle? style;
  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: widthFactor,
    child: Stack(
      children: [
        // An empty line of the style, which gives the bar its height.
        Text('', style: style),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/overflow_text/overflow_text.dart';
import 'dashboard_card.dart';

/// The two text lines of a dashboard card: the value and its supporting line.
///
/// Every card renders exactly these two lines, which is what keeps the four
/// cards the same height in every state.
class DashboardValue extends StatelessWidget {
  const DashboardValue({
    super.key,
    required this.value,
    required this.supporting,
    this.tooltip,
    this.selectable = false,
  });

  final String value;
  final Widget supporting;
  final String? tooltip;

  /// Selectable values are addresses the user may want to copy.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).emphasizedTextTheme.titleLarge;
    // Both lines stay single-line: the four cards keep one height at any width.
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DashboardCard.lineGap,
      children: [
        if (selectable)
          SelectableText(value, style: style, maxLines: 1)
        else
          OverflowText(value, style: style),
        supporting,
      ],
    );
    final tooltip = this.tooltip;
    return tooltip == null ? lines : Tooltip(message: tooltip, child: lines);
  }
}

/// The supporting line of a [DashboardValue] in the standard muted style.
class DashboardSupporting extends StatelessWidget {
  const DashboardSupporting(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OverflowText(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A supporting line led by an icon that carries the same color as its text.
class DashboardSupportingLine extends StatelessWidget {
  const DashboardSupportingLine({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Row(
      spacing: 4,
      children: [
        // Never taller than the line it sits on, so the card does not grow.
        Icon(icon, size: style?.fontSize ?? 16, color: color),
        Flexible(child: OverflowText(label, style: style)),
      ],
    );
  }
}

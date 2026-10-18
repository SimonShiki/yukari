import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

const _outerRadius = Radius.circular(24);
const _innerRadius = Radius.circular(4);
const _pressedRadius = BorderRadius.all(Radius.circular(16));

/// Expressive segmented container: [children] share one rounded group, with
/// large outer and small inner corners.
///
/// Unlike M3ESegmentedColumn, whose focus ring remounts its child, it keeps
/// focused text fields and buttons alive.
class FormSegments extends StatelessWidget {
  const FormSegments({
    super.key,
    required this.children,
    this.onTap,
    this.semanticLabelBuilder,
  });

  final List<Widget> children;

  /// Makes every segment tappable, as for list entries.
  final void Function(int index)? onTap;
  final String Function(int index)? semanticLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final last = children.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        for (final (i, child) in children.indexed)
          _Segment(
            // Keyed children keep their state when others come and go.
            key: child.key,
            radius: BorderRadius.vertical(
              top: i == 0 ? _outerRadius : _innerRadius,
              bottom: i == last ? _outerRadius : _innerRadius,
            ),
            onTap: onTap == null ? null : () => onTap!(i),
            semanticLabel: semanticLabelBuilder?.call(i),
            child: child,
          ),
      ],
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    super.key,
    required this.radius,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final BorderRadius radius;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    button: widget.onTap != null,
    child: TweenAnimationBuilder(
      tween: BorderRadiusTween(end: _pressed ? _pressedRadius : widget.radius),
      duration: Durations.short4,
      curve: Easing.emphasizedDecelerate,
      builder: (context, radius, child) => Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: radius!),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      child: widget.onTap == null
          ? widget.child
          : InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: widget.child,
            ),
    ),
  );
}

/// Pads a form field inside a segment.
class FieldSegment extends StatelessWidget {
  const FieldSegment({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: child);
}

/// A segment that toggles a setting from anywhere on its row.
class SwitchSegment extends StatelessWidget {
  const SwitchSegment({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Whether the setting can move at all; a disabled row shows no thumb
  /// response and swallows taps.
  final bool enabled;

  static final _thumbIcon = WidgetStateProperty<Icon>.fromMap({
    WidgetState.selected: const Icon(Icons.check_rounded),
    WidgetState.any: const Icon(Icons.close_rounded),
  });

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: M3EListItem(
        leading: Icon(icon),
        headline: Text(title),
        supportingText: Text(subtitle),
        trailing: Switch(
          value: value,
          thumbIcon: _thumbIcon,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    ),
  );
}

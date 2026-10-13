import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'form_segments.dart';

/// A titled group of settings. Its [children] are laid out as the segments of
/// one [NetworkFormSegments] container.
class NetworkFormSection extends StatefulWidget {
  const NetworkFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.description,
    this.footer,
    this.onTap,
    this.semanticLabelBuilder,
    this.collapsible = false,
  });

  final String title;
  final IconData icon;
  final String? description;
  final List<Widget> children;

  /// Shown under the segments, such as an add button.
  final Widget? footer;

  /// Makes every segment tappable, as for list entries.
  final void Function(int index)? onTap;
  final String Function(int index)? semanticLabelBuilder;

  /// Starts collapsed, for settings few users need; tapping the title
  /// toggles it.
  final bool collapsible;

  @override
  State<NetworkFormSection> createState() => _NetworkFormSectionState();
}

class _NetworkFormSectionState extends State<NetworkFormSection> {
  late bool _expanded = !widget.collapsible;

  Widget _title(ThemeData theme) {
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(widget.icon, size: 20, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.emphasizedTextTheme.titleSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
              if (widget.description case final description?)
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: _title(theme)),
          // Centered on the whole header, not just its title line.
          if (widget.collapsible)
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: Durations.medium2,
              curve: Easing.emphasizedDecelerate,
              child: Icon(Icons.expand_more, color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
    if (widget.collapsible) {
      header = Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          onTap: () => setState(() => _expanded = !_expanded),
          // Even padding keeps the indicator centered in the tap target.
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: header,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AnimatedSize(
          duration: Durations.medium4,
          curve: Easing.emphasizedDecelerate,
          alignment: Alignment.topCenter,
          // Hidden fields stay mounted, so their input and errors still count
          // when the form validates.
          child: Visibility(
            visible: _expanded,
            maintainState: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetworkFormSegments(
                  onTap: widget.onTap,
                  semanticLabelBuilder: widget.semanticLabelBuilder,
                  children: widget.children,
                ),
                if (widget.footer case final footer?) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: footer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

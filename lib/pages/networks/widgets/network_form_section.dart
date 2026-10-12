import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'form_segments.dart';

/// A titled group of settings. Its [children] are laid out as the segments of
/// one [NetworkFormSegments] container.
class NetworkFormSection extends StatelessWidget {
  const NetworkFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.description,
    this.footer,
    this.onTap,
    this.semanticLabelBuilder,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.emphasizedTextTheme.titleSmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    if (description case final description?)
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
          ),
        ),
        NetworkFormSegments(
          onTap: onTap,
          semanticLabelBuilder: semanticLabelBuilder,
          children: children,
        ),
        if (footer case final footer?) ...[
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart, child: footer),
        ],
      ],
    );
  }
}

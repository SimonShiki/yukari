import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../form_section/form_segments.dart';

/// One row of a [LinkList]: its leading icon, its label, and where it leads.
///
/// The row is tappable as a whole; [onTap] is what the link does, such as
/// navigating to a page or opening a dialog.
final class LinkListEntry {
  const LinkListEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.supportingText,
  });

  /// The leading icon, a widget so a brand mark that is not an [IconData] fits.
  final Widget icon;
  final String label;

  /// Explains what the link leads to; omitted for a one-line row.
  final String? supportingText;
  final VoidCallback onTap;
}

/// A segmented list of links: one tappable row per [LinkListEntry], each with
/// its icon, label and a trailing chevron.
///
/// Reuses [FormSegments], so it has the same expressive shape, hover and
/// press behavior as the app's form sections.
class LinkList extends StatelessWidget {
  const LinkList({super.key, required this.entries});

  final List<LinkListEntry> entries;

  @override
  Widget build(BuildContext context) => FormSegments(
    semanticLabelBuilder: (index) => entries[index].label,
    onTap: (index) => entries[index].onTap(),
    children: [
      for (final entry in entries)
        M3EListItem(
          leading: entry.icon,
          headline: Text(entry.label),
          supportingText: entry.supportingText == null
              ? null
              : Text(entry.supportingText!),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
    ],
  );
}

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'package:yukari_core/models/backend.dart';

/// How many lines a mode's description may wrap onto: [M3EListItem] clips its
/// supporting text to one line, and this is what raises that cap.
const _descriptionLines = 12;

/// One backend mode: its icon, name, description and selection radio.
class BackendModeRow extends StatelessWidget {
  const BackendModeRow({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.description,
    this.enabled = true,
    this.descriptionColor,
  });

  final BackendKind kind;
  final IconData icon;
  final String title;
  final String description;

  /// Whether this mode can be picked right now.
  final bool enabled;

  /// Overrides the description's color, as when it reports a problem.
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) => M3EListItem(
    enabled: enabled,
    leading: Icon(icon),
    headline: Text(title),
    supportingText: Text(
      description,
      maxLines: _descriptionLines,
      style: descriptionColor == null
          ? null
          : TextStyle(color: descriptionColor),
    ),
    trailing: Radio<BackendKind>(value: kind, enabled: enabled),
  );
}

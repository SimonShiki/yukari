import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../context_menu/m3e_select_menu.dart';

/// A settings row that shows its current choice as trailing text and opens an
/// M3 Expressive selection menu anywhere on the row.
///
/// The widget is stateless: bind [value] with a `SignalBuilder` and persist
/// [onSelected] through the controller.
class SelectItem<T> extends StatelessWidget {
  const SelectItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    this.supportingText,
  });

  /// The leading icon naming the setting.
  final IconData icon;
  final String label;

  /// Explains what the setting changes; omitted for a one-line row.
  final String? supportingText;

  /// The current choice, shown as trailing text.
  final T value;
  final List<T> options;

  /// The user-facing name of an option, used both in the menu and trailing.
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return M3ESelectMenu<T>(
      options: options,
      value: value,
      labelOf: labelOf,
      onSelected: onSelected,
      child: M3EListItem(
        leading: Icon(icon),
        headline: Text(label),
        supportingText: supportingText == null ? null : Text(supportingText!),
        trailing: Text(
          labelOf(value),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

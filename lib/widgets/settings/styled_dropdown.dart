import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

class StyledDropdown<T> extends StatelessWidget {
  const StyledDropdown({
    super.key,
    required this.items,
    required this.hintText,
    required this.onSelectionChanged,
    this.width = 150,
  });

  final List<M3EDropdownItem<T>> items;
  final String hintText;
  final ValueChanged<List<M3EDropdownItem<T>>> onSelectionChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: M3EDropdownMenu<T>(
        singleSelect: true,
        items: items,
        openMotion: M3EMotion.expressiveEffectsFast,
        closeMotion: M3EMotion.expressiveEffectsFast,
        fieldStyle: M3EDropdownFieldStyle(
          backgroundColor: colorScheme.surfaceContainerHighest,
          hintText: hintText,
          hintStyle: textTheme.bodyMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          focusedBorder: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        itemStyle: M3EDropdownItemStyle(
          outerRadius: 18.0,
          innerRadius: 6.0,
          textStyle: textTheme.bodyMedium,
          itemGap: 3.0,
          itemPadding: EdgeInsets.all(12.0),
          pressedScale: 0.98,
          selectedIcon: const Icon(Icons.check_rounded),
        ),
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

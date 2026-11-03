import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/multi_selection.dart';
import 'selection_chrome.dart';

/// A page's app bar slot that follows selection mode: the page's own [bar],
/// or the [SelectionAppBar] while [selection] is selecting.
///
/// Only this slot watches the mode, so entering selection leaves the page and
/// its list alone. The slot claims the taller bar's height and caps each bar
/// at its own, the way [Scaffold] caps one, so the body sits right under
/// whichever bar shows.
class SelectionAppBarSwitch extends StatelessWidget
    implements PreferredSizeWidget {
  const SelectionAppBarSwitch({
    super.key,
    required this.selection,
    required this.bar,
  });

  final MultiSelection selection;
  final PreferredSizeWidget bar;

  PreferredSizeWidget get _selectionBar =>
      SelectionAppBar(selection: selection);

  @override
  Size get preferredSize => Size.fromHeight(
    bar.preferredSize.height > _selectionBar.preferredSize.height
        ? bar.preferredSize.height
        : _selectionBar.preferredSize.height,
  );

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final shown = selection.selecting.value ? _selectionBar : bar;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              AppBar.preferredHeightFor(context, shown.preferredSize) +
              MediaQuery.paddingOf(context).top,
        ),
        child: shown,
      );
    },
  );
}

/// A page's floating action button slot that follows selection mode: the
/// page's own [menu], or [selecting] while [selection] is selecting. A null
/// [menu] leaves the slot empty outside selection.
class SelectionFabSwitch extends StatelessWidget {
  const SelectionFabSwitch({
    super.key,
    required this.selection,
    required this.selecting,
    this.menu,
  });

  final MultiSelection selection;
  final Widget selecting;
  final Widget? menu;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) =>
        selection.selecting.value ? selecting : menu ?? const SizedBox.shrink(),
  );
}

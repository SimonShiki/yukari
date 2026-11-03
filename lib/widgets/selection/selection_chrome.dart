import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/multi_selection.dart';
import '../../l10n/l10n.dart';

/// The selection affordance a row shows in its trailing slot: a filled check
/// when it is in the selection, a hollow circle when it is not.
///
/// One 24 dp box on both list pages, so a network row and a bookmark row read
/// as the same selection. The row centres it: a card row's own [Row] centres
/// its children, and a bookmark row takes the two-line alignment.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 24,
      child: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 24,
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    );
  }
}

/// The app bar a list page wears while it selects: close on the left, how many
/// are selected, select-all on the right.
///
/// It replaces the page's own [AppBar] in the same slot, so the title style and
/// the layout around it stay the page's.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({super.key, required this.selection});

  final MultiSelection selection;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      leading: IconButton(
        tooltip: l10n.selectionExit,
        onPressed: selection.exit,
        icon: const Icon(Icons.close_rounded),
      ),
      title: SignalBuilder(
        builder: (context) =>
            Text(l10n.selectionSelected(selection.count.value)),
      ),
      actions: [
        SignalBuilder(
          builder: (context) {
            final all = selection.allSelected.value;
            return IconButton(
              isSelected: all,
              tooltip: all
                  ? l10n.selectionDeselectAll
                  : l10n.selectionSelectAll,
              onPressed: selection.toggleAll,
              icon: const Icon(Icons.select_all_rounded),
            );
          },
        ),
      ],
    );
  }
}

/// The app bar action both list pages offer to enter selection mode.
class SelectionEntry extends StatelessWidget {
  const SelectionEntry({super.key, required this.selection});

  final MultiSelection selection;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.selectionEnter,
    onPressed: selection.enter,
    icon: const Icon(Icons.checklist_rounded),
  );
}

/// Keeps the page's back gesture and Escape inside selection mode.
///
/// Entering selection takes the keyboard focus, so Escape reaches the binding
/// below even when nothing else in the page holds it.
class SelectionScope extends StatefulWidget {
  const SelectionScope({
    super.key,
    required this.selection,
    required this.child,
  });

  final MultiSelection selection;
  final Widget child;

  @override
  State<SelectionScope> createState() => _SelectionScopeState();
}

class _SelectionScopeState extends State<SelectionScope> {
  final FocusNode _focus = FocusNode(
    debugLabel: 'selection',
    skipTraversal: true,
  );

  EffectCleanup? _stopWatching;

  @override
  void initState() {
    super.initState();
    _stopWatching = effect(() {
      if (widget.selection.selecting.value) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _stopWatching?.call();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _exit},
      child: PopScope(
        canPop: !widget.selection.selecting.value,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _exit();
        },
        child: Focus(focusNode: _focus, child: widget.child),
      ),
    ),
  );

  /// Leaves selection; back and Escape ask for it instead of leaving the page.
  void _exit() => widget.selection.exit();
}

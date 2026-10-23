import 'package:signals/signals.dart';

/// The gallery-style selection a list page runs over its own ids.
///
/// [selectable] is the page's live id list, so a target that is deleted or
/// filtered out stops counting without the page pruning anything: [count] and
/// [allSelected] are read against it, and [orderedSelection] leaves the rest
/// out.
class MultiSelection {
  MultiSelection({required this.selectable});

  /// The ids the page can select, in the order it shows them.
  final ReadonlySignal<List<String>> selectable;

  /// Whether the page is in selection mode.
  final Signal<bool> selecting = signal(false);

  /// The selected ids; it may still hold one [selectable] no longer lists.
  final Signal<Set<String>> ids = signal(const <String>{});

  /// How many selectable targets are selected.
  late final ReadonlySignal<int> count = computed(
    () => selectable.value.where(ids.value.contains).length,
  );

  /// Whether every selectable target is selected, which needs one to exist.
  late final ReadonlySignal<bool> allSelected = computed(
    () =>
        selectable.value.isNotEmpty && count.value == selectable.value.length,
  );

  /// The selected ids in the order the page shows them.
  List<String> get orderedSelection => [
    for (final id in selectable.value)
      if (ids.value.contains(id)) id,
  ];

  /// Enters selection mode with nothing selected.
  void enter() {
    if (selecting.value) return;
    ids.value = const <String>{};
    selecting.value = true;
  }

  /// Leaves selection mode and forgets what was selected.
  void exit() {
    if (!selecting.value) return;
    selecting.value = false;
    ids.value = const <String>{};
  }

  void toggle(String id) {
    ids.value = ids.value.contains(id)
        ? ({...ids.value}..remove(id))
        : {...ids.value, id};
  }

  /// Replaces the selection with [next].
  void select(Iterable<String> next) => ids.value = next.toSet();

  /// Selects every selectable target, or clears when they all already are.
  void toggleAll() {
    ids.value = allSelected.value
        ? const <String>{}
        : selectable.value.toSet();
  }

  /// Frees the signals this selection owns.
  void dispose() {
    selecting.dispose();
    ids.dispose();
    count.dispose();
    allSelected.dispose();
  }
}

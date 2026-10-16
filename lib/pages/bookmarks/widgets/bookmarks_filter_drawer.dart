import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';

/// The end drawer's filters: one single-select category, multi-select tags and
/// the clear action.
class BookmarksFilterDrawer extends StatelessWidget {
  const BookmarksFilterDrawer({super.key, required this.controller});

  final BookmarksController controller;

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.bookmarksFilters,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  SignalBuilder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.filter_list_off),
                      tooltip: l10n.bookmarksClearFilters,
                      onPressed: controller.activeFilterCount.value > 0
                          ? controller.clearFilters
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.bookmarksFiltersDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: SignalBuilder(
                builder: (context) {
                  final categories = controller.categoryOptions.value;
                  final tags = controller.tagOptions.value;
                  if (categories.isEmpty && tags.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.bookmarksNoFilters,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      if (categories.isNotEmpty) ...[
                        _label(context, l10n.bookmarksFilterCategory),
                        for (final category in categories)
                          _FilterTile(
                            selected: () =>
                                controller.category.value == category,
                            label: category,
                            onChanged: () =>
                                controller.toggleCategory(category),
                          ),
                      ],
                      if (tags.isNotEmpty) ...[
                        _label(context, l10n.bookmarksFilterTags),
                        for (final tag in tags)
                          _FilterTile(
                            selected: () => controller.tags.value.contains(tag),
                            label: '#$tag',
                            onChanged: () => controller.toggleTag(tag),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One filter value: a category, selected alone, or a tag, selected alongside
/// any other. Both are the same checkbox, so they share one tile.
class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  /// Whether this value is currently filtered on; re-read on every signal
  /// change, as the builder wraps the read.
  final bool Function() selected;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => CheckboxListTile(
      value: selected(),
      onChanged: (_) => onChanged(),
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

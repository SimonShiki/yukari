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
                          _CategoryTile(
                            controller: controller,
                            category: category,
                          ),
                      ],
                      if (tags.isNotEmpty) ...[
                        _label(context, l10n.bookmarksFilterTags),
                        for (final tag in tags)
                          _TagTile(controller: controller, tag: tag),
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

/// One category, selected alone: choosing another replaces it.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.controller, required this.category});

  final BookmarksController controller;
  final String category;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => CheckboxListTile(
      value: controller.category.value == category,
      onChanged: (_) => controller.toggleCategory(category),
      title: Text(category),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

/// One tag, selected alongside any other.
class _TagTile extends StatelessWidget {
  const _TagTile({required this.controller, required this.tag});

  final BookmarksController controller;
  final String tag;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => CheckboxListTile(
      value: controller.tags.value.contains(tag),
      onChanged: (_) => controller.toggleTag(tag),
      title: Text('#$tag'),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

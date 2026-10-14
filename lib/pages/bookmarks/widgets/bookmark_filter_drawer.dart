import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';

/// The filter sidebar of the bookmarks page: the categories and tags in use,
/// opened by the filter button in the app bar's top-right corner.
class BookmarkFilterDrawer extends StatelessWidget {
  const BookmarkFilterDrawer({super.key, required this.controller});

  final BookmarksController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final categories = controller.categories.value;
      final tags = controller.availableTags.value;
      final selectedCategory = controller.category.value;
      final selectedTags = controller.tags.value;

      return Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.bookmarksFilters,
                      style: theme.emphasizedTextTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.bookmarksClearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    onPressed: controller.filtered
                        ? controller.clearFilters
                        : null,
                  ),
                ],
              ),
              Text(
                context.l10n.bookmarksFiltersDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (categories.isEmpty && tags.isEmpty)
                Text(
                  context.l10n.bookmarksNoFilters,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else ...[
                if (categories.isNotEmpty) ...[
                  _label(context, context.l10n.bookmarksFilterCategory),
                  for (final category in categories)
                    CheckboxListTile(
                      value: selectedCategory == category,
                      onChanged: (checked) => controller.category.value =
                          checked == true ? category : null,
                      title: Text(category),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _label(context, context.l10n.bookmarksFilterTags),
                  for (final tag in tags)
                    CheckboxListTile(
                      value: selectedTags.contains(tag),
                      onChanged: (_) => controller.toggleTag(tag),
                      title: Text('#$tag'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

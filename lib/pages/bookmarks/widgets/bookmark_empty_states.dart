import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/empty_state/empty_state.dart';

/// Shown when no bookmark exists yet: built-in shared nodes aside, the user
/// has nothing to reuse.
class BookmarksEmptyState extends StatelessWidget {
  const BookmarksEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.bookmark_add_outlined,
    title: context.l10n.bookmarksEmpty,
    message: context.l10n.bookmarksEmptyDescription,
    action: FilledButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.bookmarksAdd),
    ),
  );
}

/// Shown when bookmarks exist but the search or the filters hide all of them.
class BookmarksNoMatchesState extends StatelessWidget {
  const BookmarksNoMatchesState({super.key, required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off,
    title: context.l10n.bookmarksNoResults,
    message: context.l10n.bookmarksNoResultsDescription,
    action: TextButton(
      onPressed: onClearFilters,
      child: Text(context.l10n.bookmarksClearFilters),
    ),
  );
}

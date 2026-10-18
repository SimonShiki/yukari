import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';
import '../../../widgets/empty_state/empty_state.dart';
import 'bookmarks_sections.dart';

/// The list area under the search bar: the sections, or the no-results state
/// when the filters left nothing to show.
class BookmarksBody extends StatelessWidget {
  const BookmarksBody({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onAddToNetwork,
  });

  final BookmarksController controller;
  final void Function(Bookmark bookmark) onEdit;
  final void Function(Bookmark bookmark) onDelete;
  final void Function(Bookmark bookmark) onShare;
  final void Function(Bookmark bookmark) onAddToNetwork;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => controller.hasMatches.value
        ? BookmarksSections(
            controller: controller,
            onEdit: onEdit,
            onDelete: onDelete,
            onShare: onShare,
            onAddToNetwork: onAddToNetwork,
          )
        : EmptyState(
            icon: Icons.search_off,
            title: context.l10n.bookmarksNoResults,
            message: context.l10n.bookmarksNoResultsDescription,
            action: TextButton(
              onPressed: controller.clearFilters,
              child: Text(context.l10n.bookmarksClearFilters),
            ),
          ),
  );
}

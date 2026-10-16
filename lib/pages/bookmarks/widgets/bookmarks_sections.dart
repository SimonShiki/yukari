import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/section_list.dart';
import '../../../widgets/list_editor/list_editor_segments.dart';
import 'bookmark_row.dart';

/// The two bookmark sections: the read-only shared nodes first, then the
/// user's own bookmarks, which tap through to the editor.
class BookmarksSections extends StatelessWidget {
  const BookmarksSections({
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

  BookmarkRow _row(Bookmark bookmark) => BookmarkRow(
    key: ValueKey(bookmark.id),
    bookmark: bookmark,
    onAddToNetwork: () => onAddToNetwork(bookmark),
    onShare: () => onShare(bookmark),
    onEdit: () => onEdit(bookmark),
    onDelete: () => onDelete(bookmark),
  );

  @override
  Widget build(BuildContext context) => SectionList(
    children: [
      SignalBuilder(
        builder: (context) => FormSection(
          title: context.l10n.bookmarksSectionShared,
          description: context.l10n.bookmarksSectionSharedDescription,
          icon: Icons.public,
          children: [
            for (final bookmark in controller.sharedBookmarks.value)
              _row(bookmark),
          ],
        ),
      ),
      SignalBuilder(
        builder: (context) {
          final mine = controller.myBookmarks.value;
          return FormSection(
            title: context.l10n.bookmarksSectionMine,
            icon: Icons.bookmark,
            // The empty placeholder is not an entry to edit or label.
            onTap: mine.isEmpty ? null : (index) => onEdit(mine[index]),
            semanticLabelBuilder: mine.isEmpty
                ? null
                : (index) =>
                      context.l10n.bookmarksEditNamed(mine[index].displayName),
            children: mine.isEmpty
                ? [
                    EmptyListSegment(
                      icon: Icons.bookmark_add_outlined,
                      text: context.l10n.bookmarksEmpty,
                    ),
                  ]
                : [for (final bookmark in mine) _row(bookmark)],
          );
        },
      ),
    ],
  );
}

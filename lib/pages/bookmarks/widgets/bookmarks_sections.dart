import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';
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

  BookmarkRow _row(
    Bookmark bookmark, {
    required bool selecting,
    required Set<String> selected,
  }) => BookmarkRow(
    key: ValueKey(bookmark.id),
    bookmark: bookmark,
    selecting: selecting,
    selected: selected.contains(bookmark.id),
    onAddToNetwork: () => onAddToNetwork(bookmark),
    onShare: () => onShare(bookmark),
    onEdit: () => onEdit(bookmark),
    onDelete: () => onDelete(bookmark),
  );

  @override
  Widget build(BuildContext context) {
    final selection = controller.selection;
    return SectionList(
      children: [
        SignalBuilder(
          builder: (context) {
            final selecting = selection.selecting.value;
            final selected = selection.ids.value;
            final shared = controller.sharedBookmarks.value;
            return FormSection(
              title: context.l10n.bookmarksSectionShared,
              description: context.l10n.bookmarksSectionSharedDescription,
              icon: Icons.public,
              onTap: selecting
                  ? (index) => selection.toggle(shared[index].id)
                  : null,
              children: [
                for (final bookmark in shared)
                  _row(bookmark, selecting: selecting, selected: selected),
              ],
            );
          },
        ),
        SignalBuilder(
          builder: (context) {
            final selecting = selection.selecting.value;
            final selected = selection.ids.value;
            final mine = controller.myBookmarks.value;
            return FormSection(
              title: context.l10n.bookmarksSectionMine,
              icon: Icons.bookmark,
              // The empty placeholder is not an entry to edit, label or select.
              onTap: mine.isEmpty
                  ? null
                  : selecting
                  ? (index) => selection.toggle(mine[index].id)
                  : (index) => onEdit(mine[index]),
              // Editing is what the tap does, so the label only names it then.
              semanticLabelBuilder: mine.isEmpty || selecting
                  ? null
                  : (index) => context.l10n.bookmarksEditNamed(
                      mine[index].displayName,
                    ),
              children: mine.isEmpty
                  ? [
                      EmptyListSegment(
                        icon: Icons.bookmark_add_outlined,
                        text: context.l10n.bookmarksEmpty,
                      ),
                    ]
                  : [
                      for (final bookmark in mine)
                        _row(
                          bookmark,
                          selecting: selecting,
                          selected: selected,
                        ),
                    ],
            );
          },
        ),
      ],
    );
  }
}

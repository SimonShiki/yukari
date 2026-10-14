import 'package:material_ui/material_ui.dart';

import '../../../constants/builtin_bookmarks.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/form_section/section_list.dart';
import '../../networks/widgets/list_editor_segments.dart';

/// The bookmarks page's list: the built-in shared nodes first, then the
/// user's own bookmarks.
class BookmarkSections extends StatelessWidget {
  const BookmarkSections({
    super.key,
    required this.bookmarks,
    required this.itemBuilder,
    required this.onEdit,
  });

  final List<Bookmark> bookmarks;

  /// Builds one row, so the page keeps the actions each bookmark offers.
  final Widget Function(Bookmark bookmark) itemBuilder;

  /// Opens one of the user's own bookmarks for editing; shared nodes are
  /// read-only and stay untappable.
  final void Function(Bookmark bookmark) onEdit;

  @override
  Widget build(BuildContext context) {
    final shared = [
      for (final bookmark in bookmarks)
        if (isBuiltinBookmark(bookmark)) bookmark,
    ];
    final mine = [
      for (final bookmark in bookmarks)
        if (!isBuiltinBookmark(bookmark)) bookmark,
    ];

    return SectionList(
      children: [
        if (shared.isNotEmpty)
          FormSection(
            title: context.l10n.bookmarksSectionShared,
            icon: Icons.public,
            description: context.l10n.bookmarksSectionSharedDescription,
            children: [for (final bookmark in shared) itemBuilder(bookmark)],
          ),
        FormSection(
          title: context.l10n.bookmarksSectionMine,
          icon: Icons.bookmark,
          description: context.l10n.bookmarksSectionMineDescription,
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
              : [for (final bookmark in mine) itemBuilder(bookmark)],
        ),
      ],
    );
  }
}

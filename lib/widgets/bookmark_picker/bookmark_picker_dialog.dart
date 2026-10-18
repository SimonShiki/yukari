import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'package:yukari_core/models/bookmark.dart';
import '../../utils/bookmark_search.dart';

/// Asks the user which of [bookmarks] to add, and returns the chosen ones.
///
/// Returns null when the dialog is dismissed.
Future<List<Bookmark>?> showBookmarkPicker(
  BuildContext context, {
  required List<Bookmark> bookmarks,
}) => showDialog<List<Bookmark>>(
  context: context,
  builder: (context) => _BookmarkPickerDialog(bookmarks: bookmarks),
);

class _BookmarkPickerDialog extends StatefulWidget {
  const _BookmarkPickerDialog({required this.bookmarks});

  final List<Bookmark> bookmarks;

  @override
  State<_BookmarkPickerDialog> createState() => _BookmarkPickerDialogState();
}

class _BookmarkPickerDialogState extends State<_BookmarkPickerDialog> {
  final _search = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Bookmark> get _shown => [
    for (final bookmark in widget.bookmarks)
      if (bookmarkMatches(bookmark, _search.text)) bookmark,
  ];

  @override
  Widget build(BuildContext context) {
    final available = widget.bookmarks;
    final shown = _shown;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.l10n.bookmarksPickerTitle),
      content: SizedBox(
        // Narrow on phones, and never a wall of text on a wide window.
        width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
        height: MediaQuery.of(context).size.height * 0.6,
        child: available.isEmpty
            ? Center(
                child: Text(
                  context.l10n.bookmarksPickerEmpty,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchBar(
                    controller: _search,
                    elevation: WidgetStateProperty.all(0.0),
                    hintText: context.l10n.bookmarksSearchHint,
                    leading: const Icon(Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final bookmark = shown[index];
                        return CheckboxListTile(
                          value: _selected.contains(bookmark.id),
                          onChanged: (checked) => setState(() {
                            checked == true
                                ? _selected.add(bookmark.id)
                                : _selected.remove(bookmark.id);
                          }),
                          title: Text(
                            bookmark.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            bookmark.tags.isEmpty
                                ? bookmark.address
                                : '${bookmark.address} · ${bookmark.tags.join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: M3EContainer(
                            Shapes.c4SidedCookie,
                            width: 40,
                            height: 40,
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.dns_outlined,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                  for (final bookmark in available)
                    if (_selected.contains(bookmark.id)) bookmark,
                ]),
          child: Text(context.l10n.bookmarksPickerAdd(_selected.length)),
        ),
      ],
    );
  }
}

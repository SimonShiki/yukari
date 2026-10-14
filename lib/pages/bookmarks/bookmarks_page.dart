import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../constants/builtin_bookmarks.dart';
import '../../controllers/bookmarks_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/bookmark.dart';
import '../../signals/bookmarks.dart' as saved;
import 'widgets/bookmark_delete_dialog.dart';
import 'widgets/bookmark_editor_dialog.dart';
import 'widgets/bookmark_empty_states.dart';
import 'widgets/bookmark_filter_drawer.dart';
import 'widgets/bookmark_list_item.dart';
import 'widgets/bookmark_network_picker.dart';
import 'widgets/bookmark_sections.dart';
import 'widgets/bookmark_share_sheet.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key, this.controller});

  final BookmarksController? controller;

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late final BookmarksController _controller =
      widget.controller ?? BookmarksController(showMessage: _showMessage);
  final _search = TextEditingController();
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _search.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() => showDialog<void>(
    context: context,
    builder: (context) => BookmarkEditorDialog(onSave: _controller.add),
  );

  Future<void> _edit(Bookmark bookmark) => showDialog<void>(
    context: context,
    builder: (context) =>
        BookmarkEditorDialog(initial: bookmark, onSave: _controller.update),
  );

  Future<void> _delete(Bookmark bookmark) async {
    if (await confirmBookmarkDeletion(context, bookmark)) {
      await _controller.delete(bookmark);
    }
  }

  void _clearSearch() {
    _search.clear();
    _controller.query.value = '';
  }

  void _clearFilters() {
    _search.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final visible = _controller.visible.value;
      final hasAny = _controller.all.value.isNotEmpty;

      return Scaffold(
        key: _scaffold,
        endDrawer: BookmarkFilterDrawer(controller: _controller),
        appBar: AppBar(
          title: Text(context.l10n.navBookmarks),
          actions: [
            IconButton(
              tooltip: context.l10n.bookmarksExportFile,
              onPressed: saved.bookmarks.value.isEmpty
                  ? null
                  : () => _controller.exportToFile(),
              icon: const Icon(Icons.file_download_outlined),
            ),
            IconButton(
              tooltip: context.l10n.bookmarksFilters,
              onPressed: () => _scaffold.currentState?.openEndDrawer(),
              icon: Badge(
                isLabelVisible: _controller.activeFilterCount > 0,
                label: Text('${_controller.activeFilterCount}'),
                child: const Icon(Icons.filter_list),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (hasAny)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchBar(
                    controller: _search,
                    elevation: WidgetStateProperty.all(0.0),
                    hintText: context.l10n.bookmarksSearchHint,
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_search.text.isNotEmpty)
                        IconButton(
                          tooltip: context.l10n.bookmarksSearchClear,
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                    onChanged: (value) => _controller.query.value = value,
                  ),
                ),
              Expanded(
                child: !hasAny
                    ? BookmarksEmptyState(onCreate: _create)
                    : visible.isEmpty
                    ? BookmarksNoMatchesState(onClearFilters: _clearFilters)
                    : BookmarkSections(
                        bookmarks: visible,
                        itemBuilder: _item,
                        onEdit: _edit,
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: M3EFabMenu(
          icon: Icon(
            Icons.add_rounded,
            semanticLabel: context.l10n.bookmarksAdd,
          ),
          closeIcon: Icon(
            Icons.close_rounded,
            semanticLabel: context.l10n.commonCancel,
          ),
          items: [
            M3EFabMenuItem(
              icon: const Icon(Icons.bookmark_add_outlined),
              label: context.l10n.bookmarksAdd,
              onPressed: _create,
            ),
            M3EFabMenuItem(
              icon: const Icon(Icons.file_open_outlined),
              label: context.l10n.bookmarksImportFile,
              onPressed: _controller.importFromFile,
            ),
            M3EFabMenuItem(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: context.l10n.bookmarksScanQr,
              onPressed: _controller.scanQrCode,
            ),
          ],
        ),
      );
    },
  );

  Widget _item(Bookmark bookmark) => BookmarkListItem(
    bookmark: bookmark,
    onAddToNetwork: () =>
        showNetworkPicker(context, bookmark: bookmark, controller: _controller),
    onShare: () => showBookmarkShareSheet(
      context,
      bookmark: bookmark,
      controller: _controller,
    ),
    onEdit: isBuiltinBookmark(bookmark) ? null : () => _edit(bookmark),
    onDelete: isBuiltinBookmark(bookmark) ? null : () => _delete(bookmark),
  );
}

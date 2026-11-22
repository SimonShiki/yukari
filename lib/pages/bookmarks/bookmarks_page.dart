import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/bookmarks_actions.dart';
import '../../controllers/bookmarks_controller.dart';
import '../../controllers/multi_selection.dart';
import '../../l10n/l10n.dart';
import '../../share/share_document.dart';
import '../../share/share_routes.dart';

import 'package:yukari_core/models/bookmark.dart';

import '../../widgets/empty_state/empty_state.dart';
import '../../widgets/selection/selection_chrome.dart';
import '../../widgets/selection/selection_fab_menu.dart';
import '../../widgets/selection/selection_switch.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'widgets/bookmark_delete_dialog.dart';
import 'widgets/bookmark_editor_dialog.dart';
import 'widgets/bookmark_network_picker.dart';
import 'widgets/bookmark_share_sheet.dart';
import 'widgets/bookmarks_fab_menu.dart';
import 'widgets/bookmarks_filter_drawer.dart';
import 'widgets/bookmarks_search_bar.dart';
import 'widgets/bookmarks_sections.dart';

/// Browse the built-in shared nodes and the user's bookmarks, and manage them.
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key, this.controller});

  final BookmarksController? controller;

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late final BookmarksController _controller =
      widget.controller ?? BookmarksController(showMessage: _showMessage);

  void _showMessage(String message) {
    if (mounted) showAppSnackBar(context, message);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _edit([Bookmark? bookmark]) async {
    final draft = await showBookmarkEditorDialog(context, initial: bookmark);
    if (draft == null || !mounted) return;
    await _controller.save(existing: bookmark, draft: draft);
  }

  Future<void> _delete(Bookmark bookmark) async {
    final confirmed = await showBookmarkDeleteDialog(context, bookmark);
    if (!confirmed || !mounted) return;
    await _controller.delete(bookmark);
  }

  /// Asks once for the whole selection, then deletes every saved bookmark in
  /// it; a selection holding only the built-in shared nodes deletes nothing.
  Future<void> _deleteSelection() async {
    final targets = _controller.selectedBookmarks.value;
    if (targets.isEmpty) return;
    if (!await showBookmarksDeleteDialog(context, targets) || !mounted) return;
    await _controller.deleteSelection();
  }

  Future<void> _addToNetwork(Bookmark bookmark) async {
    final networkId = await showBookmarkNetworkPicker(
      context,
      options: _controller.networkOptions(bookmark),
    );
    if (networkId == null || !mounted) return;
    await _controller.addToNetwork(bookmark, networkId);
  }

  Future<void> _share(Bookmark bookmark) => showBookmarkShareSheet(
    context,
    bookmark: bookmark,
    // The saved page resolves built-in and user bookmark ids alike.
    onShowQr: () => context.push(shareSendPath(ShareKind.node, bookmark.id)),
    onCopyAddress: () => _controller.copyAddress(bookmark),
    onExportJson: _controller.exportToFile,
  );

  @override
  Widget build(BuildContext context) {
    final selection = _controller.selection;
    final drawer = BookmarksFilterDrawer(controller: _controller);
    final body = SafeArea(child: _body());
    final fab = SelectionFabSwitch(
      selection: selection,
      selecting: SignalBuilder(
        builder: (context) => SelectionFabMenu(
          selection: selection,
          onShare: _shareSelection,
          onDelete: _controller.canDeleteSelection.value
              ? _deleteSelection
              : null,
        ),
      ),
      menu: BookmarksFabMenu(
        onAdd: _edit,
        onImport: _controller.importFromFile,
        onScan: () => context.push(shareReceivePath),
      ),
    );
    return SelectionScope(
      selection: selection,
      child: SignalBuilder(
        // The scaffold reads the app bar's preferred height when the search
        // field appears or disappears. The other slots keep their widgets.
        builder: (context) => Scaffold(
          appBar: SelectionAppBarSwitch(
            selection: selection,
            bar: _appBar(context, selection, _controller.hasBookmarks.value),
          ),
          endDrawer: drawer,
          floatingActionButton: fab,
          body: body,
        ),
      ),
    );
  }

  /// The page's own app bar: the way into selection while the filters leave
  /// something to select, the export and filter actions, and the search field.
  AppBar _appBar(
    BuildContext context,
    MultiSelection selection,
    bool hasBookmarks,
  ) {
    final l10n = context.l10n;
    return AppBar(
      title: Text(l10n.navBookmarks),
      // Nothing scrolls under a shadow over the search field below.
      scrolledUnderElevation: 0,
      actions: [
        SignalBuilder(
          builder: (context) => _controller.hasMatches.value
              ? SelectionEntry(selection: selection)
              : const SizedBox.shrink(),
        ),
        SignalBuilder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.bookmarksExportFile,
            onPressed: _controller.canExport.value
                ? _controller.exportToFile
                : null,
          ),
        ),
        SignalBuilder(
          builder: (context) => Badge(
            isLabelVisible: _controller.activeFilterCount.value > 0,
            label: Text('${_controller.activeFilterCount.value}'),
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: l10n.bookmarksFilters,
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ),
      ],
      // The field belongs to the app bar, and hides with the empty state.
      bottom: hasBookmarks
          ? PreferredSize(
              preferredSize: const Size.fromHeight(BookmarksSearchBar.height),
              child: BookmarksSearchBar(controller: _controller),
            )
          : null,
    );
  }

  /// Opens the sender on everything the selection holds.
  void _shareSelection() {
    final route = _controller.selectionShareRoute();
    if (route == null) return;
    context.push(route);
  }

  /// Nothing at all shows the full-page empty state; otherwise the list.
  Widget _body() => SignalBuilder(
    builder: (context) => _controller.hasBookmarks.value
        ? _bookmarkList()
        : EmptyState(
            icon: Icons.bookmark_add_outlined,
            title: context.l10n.bookmarksEmpty,
            message: context.l10n.bookmarksEmptyDescription,
            action: FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(context.l10n.bookmarksAdd),
            ),
          ),
  );

  Widget _bookmarkList() => SignalBuilder(
    builder: (context) => _controller.hasMatches.value
        ? BookmarksSections(
            controller: _controller,
            onEdit: _edit,
            onDelete: _delete,
            onShare: _share,
            onAddToNetwork: _addToNetwork,
          )
        : EmptyState(
            icon: Icons.search_off,
            title: context.l10n.bookmarksNoResults,
            message: context.l10n.bookmarksNoResultsDescription,
            action: TextButton(
              onPressed: _controller.clearFilters,
              child: Text(context.l10n.bookmarksClearFilters),
            ),
          ),
  );
}

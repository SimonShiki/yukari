import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/bookmarks_controller.dart';
import '../../../l10n/l10n.dart';

/// The bookmarks search field, which lives in the app bar's bottom.
///
/// Only the trailing clear button subscribes to the query, so a keystroke
/// rebuilds that button and not the field the user is typing in. The field is
/// flat: it reads as part of the app bar instead of floating above the list.
class BookmarksSearchBar extends StatelessWidget {
  const BookmarksSearchBar({super.key, required this.controller});

  /// The height the app bar reserves for the field.
  static const double height = 72;

  final BookmarksController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SearchBar(
      controller: controller.searchController,
      hintText: context.l10n.bookmarksSearchHint,
      leading: const Icon(Icons.search),
      // Part of the app bar, so it casts no shadow of its own.
      elevation: const WidgetStatePropertyAll<double>(0),
      onChanged: controller.setQuery,
      trailing: [
        SignalBuilder(
          builder: (context) => controller.query.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: context.l10n.bookmarksSearchClear,
                  onPressed: controller.clearQuery,
                ),
        ),
      ],
    ),
  );
}

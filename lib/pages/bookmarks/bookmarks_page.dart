import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navBookmarks)),
      body: Center(child: Text(context.l10n.bookmarksPage)),
    );
  }
}

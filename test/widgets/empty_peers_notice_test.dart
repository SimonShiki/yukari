import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/widgets/empty_peers_notice.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool hasPublicNodes}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Scaffold(
            body: EmptyPeersNotice(
              hasPublicNodes: hasPublicNodes,
              onAddPublic: () {},
              onBrowse: () {},
            ),
          ),
        ),
      );

  testWidgets('offers the bundled public nodes when there are any', (
    tester,
  ) async {
    await pump(tester, hasPublicNodes: true);

    expect(
      find.text(
        'This network has no initial peers, so it may not find anyone. '
        'Add a public node so it connects correctly.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add a Public Node'), findsOneWidget);
    expect(
      find.text(
        'No public nodes are bundled yet. Add a peer, or save one as a bookmark.',
      ),
      findsNothing,
    );
  });

  testWidgets('falls back to saving a bookmark without bundled nodes', (
    tester,
  ) async {
    await pump(tester, hasPublicNodes: false);

    expect(
      find.text(
        'No public nodes are bundled yet. Add a peer, or save one as a bookmark.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add a Public Node'), findsNothing);
    expect(find.text('Browse Bookmarks'), findsOneWidget);
  });
}

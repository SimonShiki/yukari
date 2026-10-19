import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/editor_exit_guard.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/widgets/network_card/network_card.dart';

import '../networks_fixture.dart';
import 'network_detail_support.dart';
import 'network_editor_support.dart';
import 'network_test_support.dart' hide pumpApp;

/// The editor's exit guard on the back paths that are not the route's own
/// gesture: the app bar, and the editor the list shows in its pane.
void main() {
  useRealDetailRouter();

  testWidgets('the app bar back button asks too, and discarding leaves', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await openEditor(tester, dirty: true);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(strings.networkDiscardTitle), findsOneWidget);
    await tester.tap(find.text(strings.networkDiscard));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkEditorPage), findsNothing);
    expect(find.byType(NetworkCard), findsWidgets);
  });

  testWidgets('the pane editor leaves its host route poppable', (tester) async {
    await tester.runAsync(seedNetworks);
    useWindow(tester, size: realRouterWindow);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        NetworkEditorPage(id: 'n1', guardKey: paneGuardKey('n1')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Invalid input, as the pane's editor can hold: the pane owns no route, so
    // it must not veto the route that hosts it.
    await tester.enterText(field(strings.networkName), '');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NetworkEditorPage), findsNothing);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/instance.dart';
import 'package:yukari/widgets/network_card/network_card_data.dart';
import 'package:yukari/widgets/network_card/network_card_list.dart';

void main() {
  var deleted = 0;
  var exported = 0;

  Future<void> pumpList(WidgetTester tester, {bool running = false}) async {
    deleted = 0;
    exported = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: NetworkCardList(
            networks: [
              NetworkCardData(
                id: 'a',
                name: 'Home',
                status: running
                    ? InstanceStatus.running
                    : InstanceStatus.stopped,
                running: running,
                onOpen: () {},
                onEdit: () {},
                onExport: () => exported++,
                onLog: () {},
                onDelete: () async => deleted++,
              ),
            ],
            onReorder: (_, _) {},
            keyBuilder: ValueKey.new,
          ),
        ),
      ),
    );
  }

  // The menu takes focus when it opens, which must not rebuild the card and
  // so dismiss the menu it hosts.
  testWidgets('one tap on the overflow button opens the menu', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('one secondary click opens the menu', (tester) async {
    await pumpList(tester);
    await tester.tapAt(
      tester.getCenter(find.text('Home')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the menu exports the network, then closes', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(exported, 1);
    expect(find.text('Export'), findsNothing);
  });

  // Export reads the saved config, so it stays available where Edit and Log
  // are not.
  testWidgets('the menu exports a running network', (tester) async {
    await pumpList(tester, running: true);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(exported, 1);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/models/instance.dart';
import 'package:yukari/widgets/network_card/network_card_data.dart';
import 'package:yukari/widgets/network_card/network_card_list.dart';

void main() {
  var deleted = 0;

  Future<void> pumpList(WidgetTester tester) async {
    deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkCardList(
            networks: [
              NetworkCardData(
                id: 'a',
                name: 'Home',
                status: InstanceStatus.stopped,
                running: false,
                onOpen: () {},
                onEdit: () {},
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
}

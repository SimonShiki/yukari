import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/context_menu/m3e_context_menu.dart';

void main() {
  var deleted = 0;

  Future<void> pumpMenu(WidgetTester tester, {double top = 100}) async {
    deleted = 0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.only(top: top),
            child: M3EContextMenu(
              tooltip: 'More',
              actions: [
                const M3EMenuAction(icon: Icons.edit, label: 'Edit'),
                M3EMenuAction(
                  icon: Icons.delete,
                  label: 'Delete',
                  destructive: true,
                  onPressed: () => deleted++,
                ),
              ],
              builder: (context, button) => SizedBox(
                height: 56,
                child: Row(children: [const Spacer(), button]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect menuRect(WidgetTester tester) => tester.getRect(
    find.byWidgetPredicate((w) => w is Material && w.elevation == 3),
  );

  testWidgets('opens below the button, aligned to its end edge', (
    tester,
  ) async {
    await pumpMenu(tester);
    final button = tester.getRect(find.byType(IconButton));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    final menu = menuRect(tester);
    expect(menu.top, moreOrLessEquals(button.bottom));
    expect(menu.right, lessThanOrEqualTo(button.right));
    expect(menu.right, greaterThan(button.left));
  });

  testWidgets('flips above the button near the bottom edge', (tester) async {
    await pumpMenu(tester, top: 700);
    final button = tester.getRect(find.byType(IconButton));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(menuRect(tester).bottom, moreOrLessEquals(button.top));
  });

  testWidgets('secondary click opens at the pointer', (tester) async {
    await pumpMenu(tester);
    await tester.tapAt(const Offset(40, 120), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(menuRect(tester).topLeft, const Offset(40, 120));
  });

  testWidgets('runs enabled actions, then closes', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget, reason: 'disabled item');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(find.text('Delete'), findsNothing);
  });
}

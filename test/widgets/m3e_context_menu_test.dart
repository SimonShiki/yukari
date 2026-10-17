import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/context_menu/m3e_context_menu.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';

void main() {
  var deleted = 0;

  Future<void> pumpMenu(
    WidgetTester tester, {
    double top = 100,
    List<M3EMenuAction>? actions,
  }) async {
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
              actions:
                  actions ??
                  [
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

  /// The background painted by the segmented item at [index].
  Color? itemColor(WidgetTester tester, int index) {
    final item = find.byWidgetPredicate(
      (w) => w is M3ESegmentedItem && w.index == index,
    );
    final container = find
        .descendant(of: item, matching: find.byType(Container))
        .first;
    return (tester.widget<Container>(container).decoration as BoxDecoration?)
        ?.color;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens below the button, aligned to its end edge', (
    tester,
  ) async {
    await pumpMenu(tester);
    final button = tester.getRect(find.byType(IconButton));
    await open(tester);

    final menu = menuRect(tester);
    expect(menu.top, moreOrLessEquals(button.bottom));
    expect(menu.right, lessThanOrEqualTo(button.right));
    expect(menu.right, greaterThan(button.left));
  });

  testWidgets('flips above the button near the bottom edge', (tester) async {
    await pumpMenu(tester, top: 700);
    final button = tester.getRect(find.byType(IconButton));
    await open(tester);

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
    await open(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget, reason: 'disabled item');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('menu items have no background of their own', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    final colors = Theme.of(tester.element(find.byType(M3ESegmentedColumn)))
        .colorScheme;
    final column = tester.widget<M3ESegmentedColumn>(
      find.byType(M3ESegmentedColumn),
    );
    expect(column.decoration?.color, Colors.transparent);
    expect(itemColor(tester, 0), Colors.transparent);
    expect(itemColor(tester, 1), Colors.transparent);
    expect(colors.surfaceContainer, isNot(Colors.transparent));
  });

  testWidgets('action entries keep their leading icons', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    final panel = find.byType(M3EMenuPanel);
    final colors = Theme.of(tester.element(panel)).colorScheme;
    for (final (icon, label) in [
      (Icons.edit, 'Edit'),
      (Icons.delete, 'Delete'),
    ]) {
      final iconFinder = find.descendant(of: panel, matching: find.byIcon(icon));
      expect(iconFinder, findsOneWidget, reason: '$label icon');
      expect(
        tester.getCenter(iconFinder).dx,
        lessThan(
          tester
              .getTopLeft(find.descendant(of: panel, matching: find.text(label)))
              .dx,
        ),
        reason: '$label icon leads its label',
      );
    }
    // The destructive entry keeps its error color.
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: panel, matching: find.byIcon(Icons.delete)),
          )
          .color,
      colors.error,
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';
import 'package:yukari/widgets/select_item/select_item.dart';

void main() {
  testWidgets('keyboard activation opens the menu below the row', (
    tester,
  ) async {
    final value = signal('English');
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: SelectItem<String>(
                icon: Icons.translate_rounded,
                label: 'Language',
                supportingText: 'The language the app shows',
                value: value.value,
                options: const ['English', '简体中文', '日本語'],
                labelOf: (option) => option,
                onSelected: (option) => value.value = option,
              ),
            ),
          ),
        ),
      ),
    );

    final row = tester.getRect(find.byType(SelectItem<String>));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(M3EMenuPanel), findsOneWidget);
    final menu = tester.getRect(
      find.byWidgetPredicate((w) => w is Material && w.elevation == 3),
    );
    // Not the screen top-left, and not some stale pointer position: the menu
    // hangs under the row it was opened from.
    expect(menu.topLeft, isNot(Offset.zero));
    expect(menu.top, moreOrLessEquals(row.bottom));
    expect(menu.left, greaterThanOrEqualTo(row.left));
    expect(menu.right, lessThanOrEqualTo(row.right));
  });
}

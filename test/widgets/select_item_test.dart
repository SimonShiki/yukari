import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';
import 'package:yukari/widgets/select_item/select_item.dart';

void main() {
  const options = ['English', '简体中文', '日本語'];
  late Signal<String> value;

  Future<void> pumpItem(WidgetTester tester) async {
    value = signal('English');
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
              child: SignalBuilder(
                builder: (context) => SelectItem<String>(
                  icon: Icons.translate_rounded,
                  label: 'Language',
                  supportingText: 'The language the app shows',
                  value: value.value,
                  options: options,
                  labelOf: (option) => option,
                  onSelected: (option) => value.value = option,
                ),
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

  Finder trailing(String text) => find.descendant(
    of: find.byType(SelectItem<String>),
    matching: find.text(text),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the selection menu where the row was tapped', (
    tester,
  ) async {
    await pumpItem(tester);
    await tester.tapAt(const Offset(40, 20));
    await tester.pumpAndSettle();

    expect(find.byType(M3EMenuPanel), findsOneWidget);
    expect(menuRect(tester).topLeft, const Offset(40, 20));
    for (final option in options) {
      expect(
        find.descendant(
          of: find.byType(M3EMenuPanel),
          matching: find.text(option),
        ),
        findsOneWidget,
        reason: 'menu lists $option',
      );
    }
    // Not the built-in dropdown widget, nor its text field.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('tapping the label, description or value opens the menu', (
    tester,
  ) async {
    for (final target in [
      'Language',
      'The language the app shows',
      'English',
    ]) {
      await pumpItem(tester);
      await tester.tap(find.text(target));
      await tester.pumpAndSettle();
      expect(find.byType(M3EMenuPanel), findsOneWidget, reason: 'tap $target');

      await tester.tapAt(const Offset(10, 780));
      await tester.pumpAndSettle();
      expect(find.byType(M3EMenuPanel), findsNothing);
    }
  });

  testWidgets('only the selected entry is highlighted and checkmarked', (
    tester,
  ) async {
    await pumpItem(tester);
    await openMenu(tester);

    final colors = Theme.of(tester.element(find.byType(M3ESegmentedColumn)))
        .colorScheme;
    final column = tester.widget<M3ESegmentedColumn>(
      find.byType(M3ESegmentedColumn),
    );
    expect(column.decoration?.color, Colors.transparent);
    expect(column.decoration?.selectedColor, colors.secondaryContainer);
    expect(column.decoration?.selectedRadius, 12);
    expect(column.isSelected, isNotNull);
    expect(column.isSelected!(0), isTrue, reason: 'English is the value');
    expect(column.isSelected!(1), isFalse);
    expect(column.isSelected!(2), isFalse);

    final selected = find.byWidgetPredicate(
      (w) => w is M3ESegmentedItem && w.isSelected,
    );
    expect(selected, findsOneWidget);
    expect(itemColor(tester, 0), colors.secondaryContainer);
    expect(itemColor(tester, 1), Colors.transparent);
    expect(itemColor(tester, 2), Colors.transparent);

    // The checkmark leads the selected entry's label.
    final checkmark = find.byIcon(Icons.check_rounded);
    expect(find.descendant(of: selected, matching: checkmark), findsOneWidget);
    expect(
      tester.getCenter(checkmark).dx,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(of: selected, matching: find.text('English')),
            )
            .dx,
      ),
    );
  });

  testWidgets('choosing an entry calls back, closes, and updates the value', (
    tester,
  ) async {
    await pumpItem(tester);
    await openMenu(tester);

    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(value.value, '日本語');
    expect(find.byType(M3EMenuPanel), findsNothing);
    expect(trailing('日本語'), findsOneWidget);
    expect(trailing('English'), findsNothing);
  });

  testWidgets('the trailing text follows the signal that binds value', (
    tester,
  ) async {
    await pumpItem(tester);
    expect(trailing('English'), findsOneWidget);

    value.value = '简体中文';
    await tester.pump();
    expect(trailing('简体中文'), findsOneWidget);
    expect(trailing('English'), findsNothing);

    await openMenu(tester);
    final items = tester.widgetList<M3ESegmentedItem>(
      find.byType(M3ESegmentedItem),
    );
    expect(
      items.toList().indexWhere((item) => item.isSelected),
      options.indexOf('简体中文'),
    );
  });

  test('lib does not use the built-in DropdownMenu', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(
      sources.where((file) => file.readAsStringSync().contains('DropdownMenu')),
      isEmpty,
    );
  });
}

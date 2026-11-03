import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/context_menu/m3e_context_menu.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';

void main() {
  var picked = '';

  /// Two selection entries: no icons, the first one currently selected.
  List<M3EMenuAction> selectionActions() => [
    M3EMenuAction(
      label: 'System',
      selected: true,
      onPressed: () => picked = 'system',
    ),
    M3EMenuAction(label: 'Dark', onPressed: () => picked = 'dark'),
  ];

  /// Pumps the menu, then opens it from its overflow button.
  Future<void> pumpSelectionMenu(
    WidgetTester tester, {
    List<M3EMenuAction>? actions,
  }) async {
    picked = '';
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: M3EContextMenu(
            tooltip: 'More',
            actions: actions ?? selectionActions(),
            builder: (context, button) => SizedBox(
              height: 56,
              child: Row(children: [const Spacer(), button]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
  }

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

  testWidgets('selection shows a checkmark and a highlight on selected', (
    tester,
  ) async {
    await pumpSelectionMenu(tester);

    final colors = Theme.of(tester.element(find.byType(M3ESegmentedColumn)))
        .colorScheme;
    final column = tester.widget<M3ESegmentedColumn>(
      find.byType(M3ESegmentedColumn),
    );
    expect(column.decoration?.color, Colors.transparent);
    expect(column.decoration?.selectedColor, colors.secondaryContainer);
    expect(column.decoration?.selectedRadius, 12);
    expect(column.isSelected, isNotNull);
    expect(column.isSelected!(0), isTrue);
    expect(column.isSelected!(1), isFalse);

    // Exactly the selected entry is painted and carries the leading checkmark.
    expect(itemColor(tester, 0), colors.secondaryContainer);
    expect(itemColor(tester, 1), Colors.transparent);
    final selectedItem = find.byWidgetPredicate(
      (w) => w is M3ESegmentedItem && w.isSelected,
    );
    expect(selectedItem, findsOneWidget);
    final checkmark = find.descendant(
      of: find.byType(M3EMenuPanel),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(checkmark, findsOneWidget);
    expect(
      find.descendant(of: selectedItem, matching: checkmark),
      findsOneWidget,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(picked, 'dark');
    expect(find.text('Dark'), findsNothing);
  });

  testWidgets('disabled selection entries stay flat and inert', (tester) async {
    await pumpSelectionMenu(
      tester,
      actions: [
        const M3EMenuAction(label: 'System', selected: true),
        M3EMenuAction(label: 'Dark', onPressed: () => picked = 'dark'),
      ],
    );

    expect(itemColor(tester, 0), Colors.transparent);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('the panel and selected pill follow the M3 menu shape tokens', (
    tester,
  ) async {
    await pumpSelectionMenu(tester);

    final panel = tester.widget<Material>(
      find.byWidgetPredicate((w) => w is Material && w.elevation == 3),
    );
    // M3 Expressive: 16dp container, 4dp item, 12dp selected item.
    expect(panel.borderRadius, BorderRadius.circular(16));
    final column = tester.widget<M3ESegmentedColumn>(
      find.byType(M3ESegmentedColumn),
    );
    expect(column.decoration?.outerRadius, 4);
    expect(column.decoration?.selectedRadius, 12);
  });

  testWidgets('hovering the selected entry keeps its selected color', (
    tester,
  ) async {
    await pumpSelectionMenu(tester);

    final colors = Theme.of(tester.element(find.byType(M3ESegmentedColumn)))
        .colorScheme;
    final column = tester.widget<M3ESegmentedColumn>(
      find.byType(M3ESegmentedColumn),
    );
    // No opaque hover fill is configured; unselected rows fall back to the
    // gray container, while the selected row keeps its selected color.
    expect(column.decoration?.hoverColor, isNull);
    final selected = find.byWidgetPredicate(
      (w) => w is M3ESegmentedItem && w.isSelected,
    );
    // The hover state layer must not paint the unselected gray over the
    // selected pill; the theme's translucent layer tints it instead.
    final ink = tester.widget<InkWell>(
      find.descendant(of: selected, matching: find.byType(InkWell)).first,
    );
    expect(ink.hoverColor, isNot(colors.surfaceContainerHighest));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(selected));
    await tester.pumpAndSettle();

    expect(itemColor(tester, 0), colors.secondaryContainer);
  });
}

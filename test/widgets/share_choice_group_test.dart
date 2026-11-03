import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/share/widgets/share_choice_group.dart';

void main() {
  const labels = ['Easy', 'Balanced', 'Fast'];

  /// The width of the group's `n` choices inside [width] once the gaps the
  /// connected layout inserts between them are taken out.
  double segment(double width) => (width - (labels.length - 1) * 2) / 3;

  Future<void> pump(
    WidgetTester tester, {
    double width = 300,
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ShareChoiceGroup(
              labels: labels,
              selectedIndex: selectedIndex,
              onSelected: onSelected ?? (_) {},
              semanticLabel: 'Density',
            ),
          ),
        ),
      ),
    ),
  );

  /// The visible choices, ahead of the copies the group stacks to measure.
  Finder buttons() => find.byType(M3EToggleButton);

  M3EToggleButtonGroup group(WidgetTester tester) =>
      tester.widget(find.byType(M3EToggleButtonGroup));

  testWidgets('splits the width evenly across the choices', (tester) async {
    await pump(tester);

    final rect = tester.getRect(find.byType(M3EToggleButtonGroup));
    expect(rect.width, closeTo(300, 0.5));
    for (var index = 0; index < labels.length; index++) {
      expect(
        tester.getSize(buttons().at(index)).width,
        closeTo(segment(300), 0.5),
        reason: 'choice $index must take an equal share',
      );
    }
    expect(tester.getRect(buttons().at(0)).left, closeTo(rect.left, 0.5));
    expect(tester.getRect(buttons().at(2)).right, closeTo(rect.right, 0.5));
  });

  testWidgets('fills a narrower container the same way', (tester) async {
    await pump(tester, width: 160);

    expect(tester.getSize(buttons().at(1)).width, closeTo(segment(160), 0.5));
  });

  testWidgets('marks only the selected choice', (tester) async {
    await pump(tester, selectedIndex: 1);

    expect(tester.widget<M3EToggleButton>(buttons().at(0)).checked, isFalse);
    expect(tester.widget<M3EToggleButton>(buttons().at(1)).checked, isTrue);
    expect(tester.widget<M3EToggleButton>(buttons().at(2)).checked, isFalse);
  });

  testWidgets('reports the tapped choice', (tester) async {
    final reported = <int>[];
    await pump(tester, selectedIndex: 0, onSelected: reported.add);

    await tester.tap(find.text(labels[2]).first);
    await tester.pump();

    expect(reported, [2]);
  });

  testWidgets('is a small connected group with every choice labelled', (
    tester,
  ) async {
    await pump(tester);

    final row = group(tester);
    expect(row.type, M3EButtonGroupType.connected);
    expect(row.size, M3EButtonSize.sm);
    expect(row.actions, hasLength(labels.length));
    for (var index = 0; index < labels.length; index++) {
      final action = row.actions[index];
      expect((action.label! as Text).data, labels[index]);
      expect(action.width, closeTo(segment(300), 0.5));
    }
  });
}

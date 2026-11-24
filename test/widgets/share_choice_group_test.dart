import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/share/widgets/share_choice_group.dart';

void main() {
  const labels = ['Easy', 'Balanced', 'Fast'];

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

  Finder buttons() => find.byType(M3EToggleButton);

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
}

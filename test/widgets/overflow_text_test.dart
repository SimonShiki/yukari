import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/overflow_text/overflow_text.dart';

void main() {
  const long = 'A peer hostname far longer than a phone can show on one line';

  Future<void> pump(WidgetTester tester, Widget child, {double width = 200}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      );

  testWidgets('reveals a truncated line on long-press', (tester) async {
    await pump(tester, const OverflowText(long), width: 80);

    // The full string is ellipsized, so nothing shows it yet.
    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.text(long), findsOneWidget);

    await tester.longPress(find.byType(OverflowText));
    await tester.pumpAndSettle();

    // The tooltip overlay carries the same full string.
    expect(find.text(long), findsNWidgets(2));
  });

  testWidgets('keeps a fitting line plain, with no tooltip', (tester) async {
    await pump(tester, const OverflowText('Home relay'), width: 300);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.text('Home relay'), findsOneWidget);
  });

  testWidgets('measures a multi-line limit', (tester) async {
    // Two lines fit in 200px; the summary below needs three.
    const twoLines = 'short';
    await pump(tester, const OverflowText(twoLines, maxLines: 2), width: 200);
    expect(find.byType(Tooltip), findsNothing);

    await pump(tester, const OverflowText(long, maxLines: 2), width: 200);
    expect(find.byType(Tooltip), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari/pages/share/widgets/block_grid.dart';

/// The page's color scheme, deterministic so the mapping can be asserted.
final ColorScheme _colors = ColorScheme.fromSeed(seedColor: Colors.blue);

/// Hosts [child] at a width that fits sixteen cells per row.
Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(colorScheme: _colors),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

/// The painter behind the grid's single [CustomPaint].
CustomPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(BlockGrid),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

void main() {
  test('maps a block status to its color', () {
    expect(blockCellColor(1, _colors), _colors.primary);
    expect(blockCellColor(2, _colors), _colors.tertiaryContainer);
    expect(blockCellColor(7, _colors), _colors.tertiaryContainer);
    expect(blockCellColor(0, _colors), _colors.surfaceContainerHighest);
  });

  testWidgets('paints many blocks with one CustomPaint', (tester) async {
    await tester.pumpWidget(_host(BlockGrid(status: List<int>.filled(40, 0))));

    // One paint pass for the whole transfer, not one widget per block.
    expect(
      find.descendant(
        of: find.byType(BlockGrid),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('speaks its description to assistive technology', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        BlockGrid(
          status: const [1, 1, 0, 2, 0],
          semanticLabel: '2 of 5 blocks decoded',
        ),
      ),
    );

    expect(find.bySemanticsLabel('2 of 5 blocks decoded'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a status signal change repaints the grid', (tester) async {
    final status = signal<List<int>>(const [0, 0, 2]);
    await tester.pumpWidget(
      _host(
        SignalBuilder(
          builder: (context) =>
              BlockGrid(status: status.value, semanticLabel: 'grid'),
        ),
      ),
    );
    final before = _painter(tester);

    status.value = const [1, 0, 2];
    await tester.pump();

    expect(_painter(tester).shouldRepaint(before), isTrue);
    // A newly decoded block pulses once, then the grid settles again.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('an identical status asks for no repaint', (tester) async {
    final status = signal<List<int>>(const [0, 1, 2]);
    await tester.pumpWidget(
      _host(
        SignalBuilder(builder: (context) => BlockGrid(status: status.value)),
      ),
    );
    final before = _painter(tester);

    // A new list with the same contents must not start a repaint or a pulse.
    status.value = const [0, 1, 2];
    await tester.pump();

    expect(_painter(tester).shouldRepaint(before), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/share/widgets/qr_matrix_view.dart';

/// A square matrix that alternates like a code, so runs merge into quads.
List<List<bool>> moduleMatrix(int size) => [
  for (var y = 0; y < size; y++)
    [for (var x = 0; x < size; x++) (x < 3 && y < 3) || (x + y).isEven],
];

/// The matrix of [QrMatrixView] as a widget of [context].
Widget _app(Widget child) => MaterialApp(home: Center(child: child));

/// The painter of the view in the tree, through the [CustomPaint] it owns.
CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(QrMatrixView),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

Future<void> _pumpView(
  WidgetTester tester,
  List<List<bool>> matrix, {
  double size = 200,
}) => tester.pumpWidget(
  _app(
    SizedBox(
      width: size,
      height: size,
      child: QrMatrixView(matrix: matrix),
    ),
  ),
);

void main() {
  testWidgets('sizes the modules in whole logical pixels', (tester) async {
    // The qrs matrix carries its own quiet zone, so 21 modules in a 200 px box
    // fit 9 px each and draw at 189 px.
    await _pumpView(tester, moduleMatrix(21));

    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(QrMatrixView),
          matching: find.byType(CustomPaint),
        ),
      ),
      const Size(189, 189),
    );
    expect(
      find.descendant(
        of: find.byType(QrMatrixView),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
      reason: 'the code repaints without repainting the page around it',
    );
  });

  testWidgets('fits a box smaller than one pixel per module', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 20,
          height: 20,
          child: QrMatrixView(matrix: moduleMatrix(21)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(QrMatrixView)), const Size(20, 20));
  });

  testWidgets('repaints for a new matrix or size, not for the same one', (
    tester,
  ) async {
    final first = moduleMatrix(21);
    final second = moduleMatrix(21);
    await _pumpView(tester, first);
    final cached = _painterOf(tester);

    await _pumpView(tester, first);
    final sameMatrix = _painterOf(tester);
    expect(
      sameMatrix.shouldRepaint(cached),
      isFalse,
      reason: 'the same matrix keeps the cached vertices',
    );

    await _pumpView(tester, second);
    final otherMatrix = _painterOf(tester);
    expect(otherMatrix.shouldRepaint(sameMatrix), isTrue);

    await _pumpView(tester, second, size: 260);
    final resized = _painterOf(tester);
    expect(
      resized.shouldRepaint(otherMatrix),
      isTrue,
      reason: 'a new module size needs new vertices',
    );
  });

  testWidgets('paints an all-white matrix without a vertex buffer', (
    tester,
  ) async {
    await _pumpView(tester, [
      for (var y = 0; y < 5; y++) List<bool>.filled(5, false),
    ]);

    expect(tester.takeException(), isNull);
  });
}

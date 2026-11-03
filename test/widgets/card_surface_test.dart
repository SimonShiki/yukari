import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/card_surface/card_surface.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );

  /// The one surface [CardSurface] paints, ignoring the Scaffold's own.
  Finder surface() => find.descendant(
    of: find.byType(CardSurface),
    matching: find.byType(Material),
  );

  testWidgets('paints the app card surface', (tester) async {
    await pump(tester, const CardSurface(child: Text('content')));

    expect(find.byType(Card), findsNothing);
    expect(find.text('content'), findsOneWidget);

    final material = tester.widget<Material>(surface());
    final colors = Theme.of(tester.element(find.byType(CardSurface)))
        .colorScheme;
    expect(material.color, colors.surfaceContainer);
    // A card is a tonal surface: elevation would put a shadow back under it.
    expect(material.elevation, 0);
    expect(material.clipBehavior, Clip.antiAlias);
    expect(
      material.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    );
  });

  testWidgets('a card with nothing to open has no ink surface', (tester) async {
    await pump(tester, const CardSurface(child: Text('content')));

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a tapping card reports the tap', (tester) async {
    var taps = 0;
    await pump(
      tester,
      CardSurface(onTap: () => taps++, child: const Text('content')),
    );

    expect(
      find.descendant(of: surface(), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    await tester.tap(find.byType(CardSurface));
    expect(taps, 1);
  });
}

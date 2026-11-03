import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/network_card/detail_container.dart';

import 'network_detail_harness.dart';
import 'network_detail_host.dart';

/// How the container moves: the open and both closes on one clock (issue 2), and
/// the fade that keeps the card's own fill at the small end (issue 3).
void main() {
  // A row low in the list, much wider than it is tall: the shape a card has.
  const card = Rect.fromLTWH(20, 300, 360, 84);
  const window = Rect.fromLTWH(0, 0, 400, 800);

  /// How far the page is out of the card, for the container's bounds.
  double opennessOf(Rect bounds) =>
      (bounds.width - card.width) / (window.width - card.width);

  /// How far the page is out of the card right now.
  double openness(WidgetTester tester) => opennessOf(container(tester));

  /// The opacity the page is painted with inside the container.
  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byKey(DetailContainer.containerKey),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// Pumps in steps until the container satisfies [done], and reports how long
  /// that took from now.
  Future<int> millisToReach(
    WidgetTester tester,
    bool Function(Rect bounds) done,
  ) async {
    for (var millis = 10; millis <= 600; millis += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      final finder = find.byKey(DetailContainer.containerKey);
      if (finder.evaluate().isEmpty) return millis;
      if (done(tester.getRect(finder))) return millis;
    }
    return -1;
  }

  /// Opens the page and reports how far it had come a quarter of the way
  /// through, and how long it took to reach the window.
  Future<(double, int)> measureOpening(WidgetTester tester) async {
    useWindow(tester);
    await openPage(tester, origin: card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final quarter = openness(tester);
    final rest = await millisToReach(
      tester,
      (bounds) => opennessOf(bounds) >= 0.999,
    );
    return (quarter, 100 + rest);
  }

  testWidgets('a plain pop repeats the opening timing', (tester) async {
    final (openedAtQuarter, opening) = await measureOpening(tester);
    expect(openedAtQuarter, greaterThan(0.5));

    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The close covers exactly the same share of its distance at the same
    // moment: it plays the open forwards, not the open's curve backwards.
    expect(1 - openness(tester), closeTo(openedAtQuarter, 0.02));

    final rest = await millisToReach(
      tester,
      (bounds) => opennessOf(bounds) <= 0.001,
    );
    expect(100 + rest, closeTo(opening, 30));
  });

  testWidgets('a committed gesture repeats the opening timing', (tester) async {
    final (openedAtQuarter, opening) = await measureOpening(tester);
    expect(openedAtQuarter, greaterThan(0.5));
    await tester.pumpAndSettle();

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.6);
    final released = openness(tester);
    await backGesture(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Same share of the remaining distance covered at the same moment.
    expect(
      (released - openness(tester)) / released,
      closeTo(openedAtQuarter, 0.02),
    );

    final rest = await millisToReach(
      tester,
      (bounds) => opennessOf(bounds) <= 0.001,
    );
    expect(100 + rest, closeTo(opening, 30));
  });

  testWidgets('the page fades in as it grows out of the card', (tester) async {
    await pumpRoute(tester, origin: card);
    expect(opacityOf(tester), 1, reason: 'opaque over the whole window');

    await backGesture(tester, 'startBackGesture', 0);
    final seen = <double>[];
    for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      await backGesture(tester, 'updateBackGestureProgress', progress);
      final opacity = opacityOf(tester);
      expect(opacity, closeTo(1 - progress, 0.001));
      seen.add(opacity);
    }

    // Invisible at the card, so the card's own fill is what shows there, and
    // never rising on the way back.
    expect(seen.last, 0);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], lessThanOrEqualTo(seen[i - 1]));
    }
  });

}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/network_card/detail_container.dart';
import 'package:yukari/widgets/network_card/network_detail_transition.dart';

import 'network_detail_host.dart';
import 'network_detail_harness.dart';

void main() {
  // A row low in the list, much wider than it is tall: the shape a card has.
  const card = Rect.fromLTWH(20, 300, 360, 84);
  const window = Rect.fromLTWH(0, 0, 400, 800);

  testWidgets('the page covers the window once the route has opened', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);

    expect(find.text('detail'), findsOneWidget);
    expect(container(tester), window);
  });

  testWidgets('the page grows out of the card frame by frame', (tester) async {
    await openPage(tester, origin: card);

    // A quarter of the way through the route's transition the page is strictly
    // between the card and the window, which is what makes the opening an
    // animation rather than a jump.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final growing = container(tester);
    expect(growing.width, greaterThan(card.width));
    expect(growing.width, lessThan(window.width));
    expect(growing.height, greaterThan(card.height));
    expect(growing.height, lessThan(window.height));

    await tester.pumpAndSettle();
    expect(container(tester), window);
  });

  testWidgets('a back gesture drags the container into the card', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);

    // Starting the gesture leaves the page over the window.
    await backGesture(tester, 'startBackGesture', 0);
    expect(container(tester), window);

    // Dragging it halfway moves and shrinks the container to exactly halfway
    // between the card and the window: the finger owns the geometry.
    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    expect(container(tester), Rect.lerp(card, window, 0.5));

    // Dragging it further follows the finger the rest of the way.
    await backGesture(tester, 'updateBackGestureProgress', 1);
    expect(container(tester), card);
  });

  testWidgets('a committed gesture carries on from where it was released', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);
    await backGesture(tester, 'startBackGesture', 0);
    // Dragged 60% of the way back, so the container is 40% open.
    await backGesture(tester, 'updateBackGestureProgress', 0.6);

    final released = container(tester);
    expect(released, Rect.lerp(card, window, 0.4));

    await backGesture(tester, 'commitBackGesture');

    // The frame the gesture is released on still shows the released size: the
    // shrink continues from the finger instead of restarting at the card.
    expect(container(tester), isNot(card));
    expect(container(tester), within(distance: 1, from: released));

    // The commit keeps the route's full duration, so where a settle scaled to
    // the distance would already have parked in the card's slot the page is
    // still on its way in.
    await tester.pump(NetworkDetailTransition.settleDuration * 0.4);
    final travelling = container(tester);
    expect(travelling.width, greaterThan(card.width));
    expect(travelling.width, lessThan(window.width));

    // It then settles into the card and the route pops.
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a cancelled gesture springs back from where it was released', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);
    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.6);
    final released = container(tester);
    expect(released, Rect.lerp(card, window, 0.4));

    await backGesture(tester, 'cancelBackGesture');

    // The spring back starts at the released size rather than at the window,
    // and finishes in proportion to the distance it has to cover.
    expect(container(tester), within(distance: 1, from: released));
    await tester.pump(NetworkDetailTransition.settleDuration * 0.6);
    expect(container(tester), window);

    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(container(tester), window);
  });

  testWidgets('a cancel hands the page back to the route without a jump', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);
    await backGesture(tester, 'startBackGesture', 0);
    // Barely dragged: a tenth of the way, so the spring back has a tenth of the
    // motion to undo, and the route's own animation finishes in a tenth of its
    // duration.
    await backGesture(tester, 'updateBackGestureProgress', 0.1);
    expect(container(tester), Rect.lerp(card, window, 0.9));

    await backGesture(tester, 'cancelBackGesture');

    // The route animates the tenth of its own duration that is left, so sample
    // the frame just before it settles and the frame just after. A spring back
    // that always took its full time regardless of the distance would still be
    // a few pixels short there, and the hand-off would snap.
    final left = NetworkDetailTransition.settleDuration * 0.1;
    await tester.pump(left - const Duration(milliseconds: 1));
    final before = container(tester);
    await tester.pump(const Duration(milliseconds: 2));
    final after = container(tester);

    expect((after.width - before.width).abs(), lessThan(1));
  });

  testWidgets('a route opened without a card still fills the window', (
    tester,
  ) async {
    await pumpRoute(tester, origin: null);

    expect(find.text('detail'), findsOneWidget);
    expect(
      find.byKey(DetailContainer.containerKey),
      findsNothing,
      reason: 'without a card there is no container to grow out of',
    );
  });

  testWidgets('leaving by the back button shrinks the page into the card', (
    tester,
  ) async {
    await pumpRoute(tester, origin: card);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The page is on its way back into the card, not covering the window.
    final leaving = container(tester);
    expect(leaving.width, lessThan(window.width));
    expect(leaving.height, lessThan(window.height));

    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}

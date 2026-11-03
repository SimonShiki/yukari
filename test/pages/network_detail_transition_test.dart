import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/widgets/network_card/network_card.dart';
import 'package:yukari/widgets/network_card/network_card_geometry.dart';
import 'package:yukari/widgets/network_card/network_detail_transition.dart';

import '../networks_fixture.dart';
import 'network_detail_support.dart';
import 'network_test_support.dart';

/// The card's own route behaviour, with the backend and the controller supplied
/// by the test. The wiring of the real page and router is covered by
/// `network_card_routing_test.dart` and `network_editor_guard_test.dart`.
void main() {
  setUp(() => networkCardOrigin.value = null);
  tearDown(() => networkCardOrigin.value = null);

  testWidgets('tapping a card opens the instance route out of that card', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpDetailList(tester);

    final card = tester.getRect(find.byType(NetworkCard).first);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkInstancePage), findsOneWidget);
    // The page filled its space, and it did so from the card that was pressed.
    expect(transitionOf(tester).origin, card);
    expect(container(tester), const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('the editor route wears the same transition', (tester) async {
    await tester.runAsync(seedNetworks);
    // Wide enough for the editor's advanced tab, still below the 840 breakpoint
    // where the list keeps a detail pane and pushes nothing.
    await pumpDetailList(tester, running: false, size: const Size(700, 800));

    final card = tester.getRect(find.byType(NetworkCard).first);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    // A network that does not run opens its editor, which grew out of the same
    // card rather than arriving with the theme's default transition.
    expect(find.byType(NetworkEditorPage), findsOneWidget);
    expect(transitionOf(tester).origin, card);
    expect(container(tester), const Rect.fromLTWH(0, 0, 700, 800));
  });

  testWidgets('the logs route keeps working and wears the transition', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpDetailList(tester);

    await tester.tap(find.byTooltip(strings.cardMoreOptions('alpha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cardLog));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(transitionOf(tester).origin, isNotNull);
  });

  testWidgets('a back gesture on the page scrubs it back into the card', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpDetailList(tester);
    final card = tester.getRect(find.byType(NetworkCard).first);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    await backGesture(tester, 'startBackGesture', 0);
    expect(container(tester), const Rect.fromLTWH(0, 0, 400, 800));

    // The gesture, not a fire-and-forget animation, decides the geometry.
    await backGesture(tester, 'updateBackGestureProgress', 1);
    expect(container(tester), card);
    expect(transitionOf(tester).animation.value, 0);

    await backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(container(tester), const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('a committed back gesture returns to the list', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpDetailList(tester);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.8);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();

    expect(find.byType(NetworkInstancePage), findsNothing);
    expect(find.byType(NetworkCard), findsWidgets);
  });

  testWidgets('a wide window keeps its detail pane and pushes nothing', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    useWindow(tester, size: const Size(1000, 800));
    final controller = NetworkPageController(
      navigate: (_, _) => fail('the wide pane must not navigate'),
      showMessage: (_) {},
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: detailBackend(),
    );
    addTearDown(controller.dispose);
    controller.start();
    await pumpDetailRouter(tester, detailRouter(controller));
    await tester.runAsync(controller.refresh);
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The pane shows the network beside the list, with no route between them.
    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(find.byType(NetworkDetailTransition), findsNothing);
    expect(containerOrNull(tester), isNull);
  });
}

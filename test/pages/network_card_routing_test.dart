import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/pages/networks/widgets/networks_list_pane.dart';
import 'package:yukari/pages/share/qr_share_send_page.dart';
import 'package:yukari/router.dart';
import 'package:yukari/widgets/network_card/network_card.dart';

import '../networks_fixture.dart';
import '../router_support.dart';
import 'network_detail_support.dart';

/// The app's own router, so the page's navigation and the route wiring are the
/// production ones: nothing here replaces `NetworksPage._navigate` or the route
/// builders.
void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  useRealDetailRouter();

  testWidgets('a tapped card hands the real route its own rect', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpApp(tester, size: realRouterWindow);

    final card = tester.getRect(find.byType(NetworkCard).first);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    // `alpha` is not running, so its card opened the editor route. The route
    // measures in the space its own page fills, which the shell's navigation
    // rail offsets from the window.
    expect(find.byType(NetworkEditorPage), findsOneWidget);
    final space = container(tester).topLeft;
    expect(transitionOf(tester).origin, card.shift(-space));
    expect(transitionOf(tester).origin!.size, card.size);
  });

  testWidgets('a deep link opens the detail route without a card rect', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    appRouter.go('/networks/instance/lab');
    await pumpApp(tester, size: const Size(400, 780));

    // No card was pressed, so there is no container to grow out of: the page
    // fills its space on its own.
    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(transitionOf(tester).origin, isNull);
    expect(containerOrNull(tester), isNull);
  });

  testWidgets('a press is not left behind for a navigation that has none', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpApp(tester, size: realRouterWindow);

    // A press hands its card to the route...
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(transitionOf(tester).origin, isNotNull);

    // ...and leaves nothing behind: the next navigation, which no press
    // preceded, opens the route without geometry instead of animating out of
    // the card pressed before.
    appRouter.go('/networks');
    await tester.pumpAndSettle();
    final pane = tester.widget<NetworksListPane>(find.byType(NetworksListPane));
    pane.onSelect(pane.controller.cards.value, 0);
    await tester.pumpAndSettle();
    expect(find.byType(NetworkEditorPage), findsOneWidget);
    expect(transitionOf(tester).origin, isNull);

    // The good path still works: the next press animates again.
    appRouter.go('/networks');
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(NetworkCard).first);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    final space = container(tester).topLeft;
    expect(transitionOf(tester).origin, card.shift(-space));
  });

  testWidgets('the card menu pushes the sender, and back returns to the list', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await pumpApp(tester, size: realRouterWindow);

    await tester.tap(find.byTooltip(strings.cardMoreOptions('alpha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cardShareQr));
    await tester.pumpAndSettle();

    // The send page is pushed above the shell: the list is covered, not
    // replaced.
    expect(find.byType(QrShareSendPage), findsOneWidget);
    expect(find.byType(NetworksPage), findsNothing);
    // `alpha` has no peers yet, so the sender says what to add.
    expect(find.text(strings.shareSendNoPeers), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(QrShareSendPage), findsNothing);
    expect(find.byType(NetworksPage), findsOneWidget);
  });
}

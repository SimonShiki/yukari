import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/pages/networks/network_instance_page.dart';
import 'package:yukari/pages/networks/editor_exit_guard.dart';
import 'package:yukari/pages/networks/network_page_dialogs.dart';
import 'package:yukari/pages/networks/networks_page.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';
import 'package:yukari/widgets/network_card/network_card_list.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';
import 'network_test_support.dart';

/// Pumps bounded frames: the wide pane keeps a frame animating, so
/// `pumpAndSettle` would never return.
Future<void> pumpWide(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  useDeterministicCursor();

  late List<String> navigated;
  late List<String> messages;
  late List<Network> warnings;

  NetworkPageController build({
    required FakeBackend backend,
    bool Function()? invalidInput,
    Future<bool> Function()? confirmDiscardDialog,
  }) => NetworkPageController(
    navigate: (route, id) => navigated.add(id == null ? route : '$route:$id'),
    showMessage: messages.add,
    confirmDelete: (_) async => true,
    showTunPermissionWarning: (network) async => warnings.add(network),
    backend: backend,
    invalidInput: invalidInput,
    confirmDiscardDialog: confirmDiscardDialog,
  );

  Future<NetworkPageController> pumpList(
    WidgetTester tester, {
    required Size size,
    FakeBackend? backend,
    bool Function()? invalidInput,
    Future<bool> Function()? confirmDiscardDialog,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = build(
      backend: backend ?? FakeBackend(),
      invalidInput: invalidInput,
      confirmDiscardDialog: confirmDiscardDialog,
    );
    addTearDown(controller.dispose);
    controller.start();
    await pumpApp(tester, NetworksPage(controller: controller), settle: settle);
    return controller;
  }

  setUp(() {
    navigated = [];
    messages = [];
    warnings = [];
  });

  testWidgets('narrow windows open the route instead of a detail pane', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final controller = await pumpList(tester, size: const Size(400, 780));
    await controller.refresh();
    await tester.pumpAndSettle();

    expect(find.byType(NetworkEditorPage), findsNothing);
    // No pane, so no row is highlighted and one tap opens the detail.
    expect(
      tester
          .widget<NetworkCardList>(find.byType(NetworkCardList))
          .selectedIndex,
      isNull,
    );

    await tester.tap(find.text('beta'));
    await tester.pumpAndSettle();

    expect(navigated, ['network-edit:n2']);
  });

  testWidgets('wide windows show the selected network beside the list', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    var running = false;
    final controller = await pumpList(
      tester,
      size: const Size(1000, 800),
      backend: FakeBackend(
        collected: () => running
            ? {
                'alpha': {'running': true},
              }
            : {},
      ),
      // The editor pane keeps the tree animating, so settle by hand.
      settle: false,
    );
    await tester.runAsync(controller.refresh);
    await tester.pump(const Duration(milliseconds: 100));

    // The first network is selected and stopped, so its editor shows.
    expect(find.byType(NetworkEditorPage), findsOneWidget);
    expect(find.byType(NetworkInstancePage), findsNothing);

    running = true;
    await tester.runAsync(controller.refresh);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(find.byType(NetworkEditorPage), findsNothing);
    expect(navigated, isEmpty);
  });

  testWidgets('a deselect on wide windows keeps the pane and asks nothing', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext pageContext;
    late NetworkPageController controller;
    controller = NetworkPageController(
      navigate: (route, id) => navigated.add(id == null ? route : '$route:$id'),
      showMessage: messages.add,
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: FakeBackend(),
      isWide: () => true,
      invalidInput: () =>
          hasInvalidInput(paneGuardKey(controller.selectedId.value ?? '')),
      confirmDiscardDialog: () => confirmDiscardChanges(pageContext),
    );
    addTearDown(controller.dispose);
    controller.start();
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          pageContext = context;
          return NetworksPage(controller: controller);
        },
      ),
      settle: false,
    );
    await tester.runAsync(controller.refresh);
    await tester.pump(const Duration(milliseconds: 100));

    // The pane's editor holds invalid input, so a deselect that consulted the
    // exit guard would prompt.
    await tester.enterText(
      find.widgetWithText(TextFormField, strings.networkName),
      '',
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tapping the selected row makes the list re-emit "nothing selected".
    await tester.tap(find.text('alpha'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(strings.networkDiscardTitle), findsNothing);
    expect(controller.selectedId.value, 'n1');
    expect(find.byType(NetworkEditorPage), findsOneWidget);
  });

  testWidgets('the detail pane tab belongs to the list controller', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final controller = await pumpList(
      tester,
      size: const Size(1000, 800),
      backend: FakeBackend(
        collected: () => {
          'alpha': {'running': true},
        },
      ),
      settle: false,
    );
    await tester.runAsync(controller.refresh);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(controller.instanceTab.value, InstanceTab.peers);

    // The pane's own tab controller writes back to the list controller.
    await tester.tap(find.text(strings.networkLogs));
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.instanceTab.value, InstanceTab.logs);

    // And the list controller drives the pane the other way.
    controller.instanceTab.value = InstanceTab.peers;
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
  });

  testWidgets('the row menu edits and logs in the wide pane', (tester) async {
    await tester.runAsync(seedNetworks);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var running = false;
    final controller = NetworkPageController(
      navigate: (route, id) => navigated.add(id == null ? route : '$route:$id'),
      showMessage: messages.add,
      confirmDelete: (_) async => true,
      showTunPermissionWarning: (_) async {},
      backend: FakeBackend(
        collected: () => running
            ? {
                'alpha': {'running': true},
              }
            : {},
      ),
      isWide: () => true,
    );
    addTearDown(controller.dispose);
    controller.start();
    await pumpApp(tester, NetworksPage(controller: controller), settle: false);
    await tester.runAsync(controller.refresh);
    await pumpWide(tester);

    // The first network is selected, so its editor is already in the pane.
    expect(find.text(strings.networkEditNamed('alpha')), findsOneWidget);

    // Edit from the second row's menu moves the pane, without a route.
    await tester.tap(find.byTooltip(strings.cardMoreOptions('beta')));
    await pumpWide(tester);
    await tester.tap(find.text(strings.commonEdit));
    await pumpWide(tester);

    expect(find.text(strings.networkEditNamed('beta')), findsOneWidget);
    expect(navigated, isEmpty);

    // A second row tap switches the pane back.
    await tester.tap(find.text('alpha'));
    await pumpWide(tester);

    expect(find.text(strings.networkEditNamed('alpha')), findsOneWidget);

    // Once it runs, the menu's Log opens the pane's logs tab.
    running = true;
    await tester.runAsync(controller.refresh);
    await pumpWide(tester);
    await tester.tap(find.byTooltip(strings.cardMoreOptions('alpha')));
    await pumpWide(tester);
    await tester.tap(find.text(strings.cardLog));
    await pumpWide(tester);

    expect(controller.instanceTab.value, InstanceTab.logs);
    expect(find.byType(NetworkInstancePage), findsOneWidget);
    expect(find.text(strings.networkNoEvents), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(navigated, isEmpty);
  });

  testWidgets('a failed refresh shows the banner and can retry', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final backend = CountingBackend(failCollect: true);
    final controller = await pumpList(
      tester,
      size: const Size(400, 780),
      backend: backend,
    );

    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);

    final before = backend.collects;
    await tester.runAsync(() async {
      await tester.tap(find.text(strings.commonRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(backend.collects, greaterThan(before));
  });

  testWidgets('leaving invalid input in the pane asks exactly once', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    var asked = 0;
    await pumpList(
      tester,
      size: const Size(1000, 800),
      invalidInput: () => true,
      confirmDiscardDialog: () async {
        asked++;
        return false;
      },
    );

    await tester.tap(find.text('beta').first);
    await tester.pumpAndSettle();

    expect(asked, 1);
  });

  testWidgets('the create menu offers create, import and scan', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpList(tester, size: const Size(400, 780));

    await tester.tap(find.byTooltip(strings.networkAdd));
    await tester.pumpAndSettle();

    expect(find.text(strings.networkCreateManually), findsOneWidget);
    expect(find.text(strings.networkImportFile), findsOneWidget);
    expect(find.text(strings.networkScanQr), findsOneWidget);

    await tester.tap(find.text(strings.networkCreateManually));
    await tester.pumpAndSettle();
    expect(navigated, ['/networks/create']);

    await tester.tap(find.byTooltip(strings.networkAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.networkScanQr));
    await tester.pumpAndSettle();

    expect(navigated, ['/networks/create', shareReceivePath]);
    expect(
      messages,
      isEmpty,
      reason: 'the scan opens the receiver, it reports',
    );
  });

  testWidgets('the row menu shares a network as a QR code', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpList(tester, size: const Size(400, 780));

    await tester.tap(find.byTooltip(strings.cardMoreOptions('alpha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cardShareQr));
    await tester.pumpAndSettle();

    expect(navigated, [shareSendPath(ShareKind.network, 'n1')]);
  });

  testWidgets('the delete dialog asks, and a cancel keeps the network', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (context_) {
          context = context_;
          return const SizedBox.shrink();
        },
      ),
    );

    final dialog = confirmDeleteNetwork(
      context,
      Network()..networkName = 'alpha',
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.networkDeleteTitle), findsOneWidget);
    expect(
      find.text(strings.networkDeleteDescription('alpha')),
      findsOneWidget,
    );

    // Deleting is destructive, so the confirm wears the theme's error pair.
    final confirm = find.widgetWithText(FilledButton, strings.commonDelete);
    final button = tester.widget<FilledButton>(confirm);
    final scheme = Theme.of(tester.element(confirm)).colorScheme;
    expect(button.style?.backgroundColor?.resolve({}), scheme.error);
    expect(button.style?.foregroundColor?.resolve({}), scheme.onError);

    await tester.tap(find.text(strings.commonCancel));
    await tester.pumpAndSettle();

    expect(await dialog, isFalse);
  });

  testWidgets('the TUN dialog explains the missing privileges', (tester) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (context_) {
          context = context_;
          return const SizedBox.shrink();
        },
      ),
    );

    final dialog = showTunPermissionWarningDialog(
      context,
      Network()..networkName = 'alpha',
      FakeBackend(),
      serviceSupported: false,
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.networkPrivileges), findsOneWidget);
    expect(
      find.textContaining(
        Platform.isWindows
            ? strings.networkTunWindows('alpha').split('\n').first
            : strings.networkTunRoot('alpha').split('\n').first,
      ),
      findsOneWidget,
    );
    expect(find.text(strings.commonCancel), findsOneWidget);

    await tester.tap(find.text(strings.commonCancel));
    await tester.pumpAndSettle();
    await dialog;
  });

  testWidgets('the TUN dialog offers settings and a restart when it can', (
    tester,
  ) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (context_) {
          context = context_;
          return const SizedBox.shrink();
        },
      ),
    );

    final dialog = showTunPermissionWarningDialog(
      context,
      Network()..networkName = 'alpha',
      _ElevatingBackend(),
      serviceSupported: true,
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.navSettings), findsOneWidget);
    expect(find.byTooltip(strings.networkRestart).evaluate(), isEmpty);
    expect(find.text(strings.networkRestart), findsOneWidget);

    await tester.tap(find.text(strings.commonCancel));
    await tester.pumpAndSettle();
    await dialog;
  });
}

/// A backend that can elevate, as Windows can.
class _ElevatingBackend extends FakeBackend {
  @override
  bool get canElevate => true;
}

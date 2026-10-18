import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_page_controller.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/networks/network_creator_page.dart';

import '../networks_fixture.dart';
import 'network_test_support.dart';

void main() {
  useDeterministicCursor();

  late List<String> navigated;
  late List<String> messages;
  late List<Network> created;
  late Completer<void>? gate;

  Future<NetworkCreatorController> pumpCreator(WidgetTester tester) async {
    final controller = NetworkCreatorController(
      navigate: navigated.add,
      showMessage: messages.add,
      add: (id, network) async {
        created.add(network);
        await gate?.future;
      },
    );
    addTearDown(controller.dispose);
    await pumpApp(tester, NetworkCreatorPage(controller: controller));
    return controller;
  }

  setUp(() {
    navigated = [];
    messages = [];
    created = [];
    gate = null;
  });

  testWidgets('an empty or duplicate name is refused', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpCreator(tester);

    await tester.tap(find.text(strings.commonCreate));
    await tester.pumpAndSettle();
    expect(find.text(strings.validationNetworkEmpty), findsOneWidget);
    expect(created, isEmpty);

    await tester.enterText(field(strings.networkName), 'alpha');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.commonCreate));
    await tester.pumpAndSettle();

    expect(find.text(strings.validationNetworkExists), findsOneWidget);
    expect(created, isEmpty);
    expect(navigated, isEmpty);
  });

  testWidgets('the hostname field stops at 32 characters', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpCreator(tester);

    await tester.enterText(field(strings.networkName), 'fresh');
    await tester.enterText(field(strings.networkHostname), 'a' * 33);
    await tester.pumpAndSettle();

    final host = tester.widget<TextField>(
      find.descendant(
        of: field(strings.networkHostname),
        matching: find.byType(TextField),
      ),
    );
    expect(host.controller!.text.length, 32);
    expect(find.text(strings.validationHostnameLength), findsNothing);
  });

  testWidgets('creates the network and opens its editor', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpCreator(tester);

    await tester.enterText(field(strings.networkName), '  fresh  ');
    await tester.enterText(field(strings.networkHostname), '  device  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.commonCreate));
    await tester.pumpAndSettle();

    expect(created.single.networkName, 'fresh');
    expect(created.single.hostname, 'device');
    expect(navigated.single, startsWith('/networks/edit/'));
    expect(messages, isEmpty);
  });

  testWidgets('a blank hostname is stored as null', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpCreator(tester);

    await tester.enterText(field(strings.networkName), 'fresh');
    await tester.enterText(field(strings.networkHostname), '   ');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.commonCreate));
    await tester.pumpAndSettle();

    expect(created.single.hostname, isNull);
  });

  testWidgets('the name field creates from its keyboard action', (tester) async {
    await tester.runAsync(seedNetworks);
    await pumpCreator(tester);

    await tester.enterText(field(strings.networkName), 'fresh');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(created.single.networkName, 'fresh');
    expect(navigated.single, startsWith('/networks/edit/'));
  });

  testWidgets('both buttons are disabled while creating', (tester) async {
    await tester.runAsync(seedNetworks);
    gate = Completer<void>();
    await pumpCreator(tester);
    await tester.enterText(field(strings.networkName), 'fresh');
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.commonCreate));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );

    gate!.complete();
    await tester.pumpAndSettle();
    expect(navigated.single, startsWith('/networks/edit/'));
  });

  testWidgets('a failed create is reported', (tester) async {
    await tester.runAsync(seedNetworks);
    final controller = NetworkCreatorController(
      navigate: navigated.add,
      showMessage: messages.add,
      add: (_, _) async => throw StateError('disk'),
    );
    addTearDown(controller.dispose);
    await pumpApp(tester, NetworkCreatorPage(controller: controller));

    await tester.enterText(field(strings.networkName), 'fresh');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.commonCreate));
    await tester.pumpAndSettle();

    expect(messages.single, contains('disk'));
    expect(navigated, isEmpty);
    expect(controller.creating.value, isFalse);
  });
}

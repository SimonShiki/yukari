import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/widgets/network_card/network_card.dart';
import 'package:yukari/widgets/network_card/predictive_back_gesture_detector.dart';

import '../networks_fixture.dart';
import 'network_detail_support.dart';
import 'network_editor_support.dart';
import 'network_test_support.dart' hide pumpApp;

/// The editor route's predictive back gesture: joined when leaving loses
/// nothing, declined while the editor holds invalid input.
void main() {
  useRealDetailRouter();

  testWidgets('a back gesture asks before it discards, keeping the page whole', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await openEditor(tester, dirty: true);
    final whole = container(tester);

    // The editor can veto the pop, so the gesture is not joined at all: the
    // page is never shrunk into a state the refusal could strand it in.
    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    expect(container(tester), whole);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();

    expect(find.text(strings.networkDiscardTitle), findsOneWidget);
    expect(container(tester), whole);

    // Keeping the edits leaves the editor open, at full size.
    await tester.tap(find.text(strings.networkKeepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkEditorPage), findsOneWidget);
    expect(container(tester), whole);
  });

  testWidgets('a valid editor joins the back gesture and shrinks away', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await openEditor(tester);
    final whole = container(tester);
    final origin = transitionOf(tester).origin!;

    await backGesture(tester, 'startBackGesture', 0);
    // Joined: the gesture is driving this route, not being declined by it.
    expect(transitionOf(tester).gesture.phase, PredictiveBackPhase.update);

    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    final scrubbed = container(tester);
    expect(scrubbed.width, lessThan(whole.width));
    expect(scrubbed.width, greaterThan(origin.width));

    await backGesture(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The commit plays the shrink into the card, and the editor leaves.
    final closing = container(tester);
    expect(closing.width, lessThan(whole.width));
    expect(closing.width, greaterThan(origin.width));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkEditorPage), findsNothing);
    expect(find.byType(NetworkCard), findsWidgets);
  });

  testWidgets('a flag that enables invalid text declines the back gesture', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    await openEditor(tester);
    final whole = container(tester);

    bool addressEnabled() =>
        tester.widget<TextFormField>(field(strings.networkIpv4)).enabled;
    Future<void> toggleDhcp() =>
        saving(tester, () => tester.tap(find.text(strings.networkDhcp)));

    // Give the manual address field invalid text, then disable it again: a
    // disabled field's validator is skipped, so the form counts valid.
    if (!addressEnabled()) await toggleDhcp();
    expect(addressEnabled(), isTrue);
    await saving(
      tester,
      () => tester.enterText(field(strings.networkIpv4), '999.999.999.999/24'),
    );
    await toggleDhcp();
    expect(addressEnabled(), isFalse);

    // An edit elsewhere re-reads the form while that field is disabled.
    await saving(
      tester,
      () => tester.enterText(field(strings.networkName), 'alpha2'),
    );

    // Re-enabling the field brings the invalid text back without any field
    // value changing. The guard has to know, so the gesture is declined and
    // back asks before discarding.
    await toggleDhcp();
    expect(addressEnabled(), isTrue);

    await backGesture(tester, 'startBackGesture', 0);
    expect(transitionOf(tester).gesture.phase, PredictiveBackPhase.idle);
    expect(container(tester), whole);

    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();

    expect(find.text(strings.networkDiscardTitle), findsOneWidget);
    expect(container(tester), whole);

    await tester.tap(find.text(strings.networkKeepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkEditorPage), findsOneWidget);
  });

  testWidgets('a permitted back from a clean editor shrinks into the card', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final card = await openEditor(tester);
    final whole = container(tester);

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    await backGesture(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // The page is on its way back into the card: neither left whole nor gone.
    final leaving = container(tester);
    expect(leaving.width, lessThan(whole.width));
    expect(leaving.width, greaterThan(card.width));

    await tester.pumpAndSettle();
    expect(find.byType(NetworkEditorPage), findsNothing);
    expect(find.byType(NetworkCard), findsWidgets);
  });
}

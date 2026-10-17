import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

import 'app_shell_support.dart';

void main() {
  final List<Widget> pages = shellPages();

  testWidgets('a swipe slides to the next page', (tester) async {
    await pumpShell(tester, pages);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();

    expect(pageOf(tester), inExclusiveRange(0.5, 1.0));
    expectSliding(tester);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pageOf(tester), 1.0);
    expect(
      viewportOf(tester),
      tester.getRect(find.byKey(const ValueKey('page-1'))),
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(mountedPage(0), findsOneWidget);
  });

  testWidgets('tapping a destination slides to its page', (tester) async {
    await pumpShell(tester, pages);

    await tester.tap(find.text('Networks'));
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(pageOf(tester), inExclusiveRange(0.0, 1.0));
    expectSliding(tester);

    await tester.pumpAndSettle();
    expect(pageOf(tester), 1.0);
    expect(mountedPage(0), findsOneWidget, reason: 'tap: page0 mounted');
  });

  testWidgets('an external page change slides without selecting its pages', (
    tester,
  ) async {
    final selected = <int>[];
    final host = await pumpShell(tester, pages, onSelected: selected.add);

    host.goTo(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(pageOf(tester), inExclusiveRange(0.0, 3.0));
    expectSliding(tester);

    await tester.pumpAndSettle();
    expect(pageOf(tester), 3.0);
    expect(
      viewportOf(tester),
      tester.getRect(find.byKey(const ValueKey('page-3'))),
    );
    expect(selected, isEmpty);
  });

  testWidgets('turning transitions off stops the swipe and jumps switches', (
    tester,
  ) async {
    final transitions = signal(false);
    addTearDown(transitions.dispose);
    final host = await pumpShell(tester, pages, transitions: transitions);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(pageOf(tester), 0.0);

    await tester.tap(find.text('Networks'));
    await tester.pump();
    expect(pageOf(tester), 1.0);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    host.goTo(3);
    await tester.pump();
    expect(pageOf(tester), 3.0);
    expect(
      viewportOf(tester),
      tester.getRect(find.byKey(const ValueKey('page-3'))),
    );

    // Turning transitions back on applies to the next gesture immediately.
    transitions.value = true;
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();
    expect(pageOf(tester), inExclusiveRange(2.0, 3.0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pageOf(tester), 2.0);
  });
}

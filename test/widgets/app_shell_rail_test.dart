import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';

import 'app_shell_support.dart';

void main() {
  final List<Widget> pages = shellPages();
  const Size wide = Size(1000, 800);
  const Size phone = Size(400, 780);

  testWidgets('the rail pager is horizontal and has no switch gesture', (
    tester,
  ) async {
    await pumpShell(tester, pages, size: wide);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(pageAxis(tester), Axis.horizontal);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(pageOf(tester), 0.0);
  });

  testWidgets('a rail destination tap slides horizontally', (tester) async {
    await pumpShell(tester, pages, size: wide);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Networks'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pageOf(tester), inExclusiveRange(0.0, 1.0));
    expectSliding(tester);

    await tester.pumpAndSettle();
    expect(pageOf(tester), 1.0);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
  });

  testWidgets('resizing keeps the page and the pages mounted', (tester) async {
    final host = await pumpShell(tester, pages, size: phone);
    await tester.tap(find.text('Networks'));
    await tester.pumpAndSettle();
    expect(pageOf(tester), 1.0);

    tester.view.physicalSize = wide;
    await tester.pumpAndSettle();
    expect(pageAxis(tester), Axis.horizontal);
    expect(pageOf(tester), 1.0);
    expect(host.index, 1);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(mountedPage(0), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = phone;
    await tester.pumpAndSettle();
    expect(pageOf(tester), 1.0);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rail tap jumps when transitions are off', (tester) async {
    final transitions = signal(false);
    addTearDown(transitions.dispose);
    await pumpShell(tester, pages, size: wide, transitions: transitions);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(pageOf(tester), 0.0);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Networks'),
      ),
    );
    await tester.pump();
    expect(pageOf(tester), 1.0);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
  });
}

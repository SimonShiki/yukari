import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/network_card/network_detail_route.dart';

import 'network_detail_host.dart';
import 'network_detail_harness.dart';

/// Closing a detail route that refuses to be popped: the page must come back to
/// full size rather than stay where the gesture left it.
void main() {
  const card = Rect.fromLTWH(20, 300, 360, 84);
  const window = Rect.fromLTWH(0, 0, 400, 800);

  testWidgets('a commit the navigator refuses comes back to full size', (
    tester,
  ) async {
    // A page-based navigator that turns every pop down, as go_router does for a
    // route whose exit guard vetoes.
    useWindow(tester);
    await tester.pumpWidget(
      const MaterialApp(home: _RefusingNavigator(origin: card)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    expect(container(tester), Rect.lerp(card, window, 0.5));
    await backGesture(tester, 'commitBackGesture');

    // The navigator kept the route, so the page has to come back out of the
    // card instead of being left mid-transform.
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(container(tester), window);
  });

  testWidgets('a pop the page refuses leaves it at full size', (tester) async {
    // A page that forbids popping, as a form with unsaved edits does.
    await pumpRoute(tester, origin: card, canPop: false);
    expect(container(tester), window);

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.7);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();

    // Nothing was shrunk, so a refused pop cannot leave a half-open page.
    expect(find.text('detail'), findsOneWidget);
    expect(container(tester), window);
  });
}

/// A page-based navigator that refuses every pop.
class _RefusingNavigator extends StatefulWidget {
  const _RefusingNavigator({required this.origin});

  final Rect origin;

  @override
  State<_RefusingNavigator> createState() => _RefusingNavigatorState();
}

class _RefusingNavigatorState extends State<_RefusingNavigator> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      MaterialPage<void>(
        key: const ValueKey('home'),
        child: Center(
          child: TextButton(
            onPressed: () => setState(() => _open = true),
            child: const Text('open'),
          ),
        ),
      ),
      if (_open) _DetailPage(origin: widget.origin),
    ],
    // go_router refuses a pop by returning false from `onPopPage`; the newer
    // `onDidRemovePage` only observes a removal and cannot refuse one.
    // ignore: deprecated_member_use
    onPopPage: (route, result) => false,
  );
}

class _DetailPage extends Page<void> {
  const _DetailPage({required this.origin})
    : super(key: const ValueKey('detail'));

  final Rect origin;

  @override
  Route<void> createRoute(BuildContext context) => NetworkDetailRoute(
    settings: this,
    origin: origin,
    builder: (context) => Scaffold(appBar: AppBar(title: const Text('detail'))),
  );
}

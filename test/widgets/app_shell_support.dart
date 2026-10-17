import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/navigation/app_shell.dart';

/// A page that fills its slot, so a slide can be measured by rectangles.
Widget _shellPage(int index) => ColoredBox(
  key: ValueKey('page-$index'),
  color: Colors.transparent,
  child: Center(child: Text('Page $index')),
);

/// One page per destination, in destination order.
List<Widget> shellPages() => [for (var i = 0; i < 4; i++) _shellPage(i)];

/// Holds the selected index the way the router does and mirrors it into the
/// shell, so a tap or swipe the shell reports is applied like the router would.
class ShellHost extends StatefulWidget {
  const ShellHost({
    super.key,
    required this.pages,
    required this.transitions,
    this.onSelected,
  });

  final List<Widget> pages;
  final ReadonlySignal<bool> transitions;
  final ValueChanged<int>? onSelected;

  @override
  State<ShellHost> createState() => ShellHostState();
}

class ShellHostState extends State<ShellHost> {
  int _index = 0;

  /// The destination the shell currently shows, as the router would know it.
  int get index => _index;

  void goTo(int index) => setState(() => _index = index);

  void _select(int index) {
    widget.onSelected?.call(index);
    goTo(index);
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentIndex: _index,
    pages: widget.pages,
    transitions: widget.transitions,
    onDestinationSelected: _select,
  );
}

/// Pumps a shell with its host on a phone-sized window, settled.
Future<ShellHostState> pumpShell(
  WidgetTester tester,
  List<Widget> pages, {
  Size size = const Size(400, 780),
  Signal<bool>? transitions,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final enabled = transitions ?? signal(true);
  if (transitions == null) addTearDown(enabled.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShellHost(
        pages: pages,
        transitions: enabled,
        onSelected: onSelected,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<ShellHostState>(find.byType(ShellHost));
}

PageView _shellPageView(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView));

double pageOf(WidgetTester tester) => _shellPageView(tester).controller!.page!;

Axis pageAxis(WidgetTester tester) => _shellPageView(tester).scrollDirection;

Rect viewportOf(WidgetTester tester) => tester.getRect(find.byType(PageView));

/// The viewport straddles two pages: the switch is running.
void expectSliding(WidgetTester tester) {
  final double page = pageOf(tester);
  expect(page, isNot(page.roundToDouble()));
  final Rect viewport = viewportOf(tester);
  for (final int index in [page.floor(), page.ceil()]) {
    expect(
      tester.getRect(find.byKey(ValueKey('page-$index'))).overlaps(viewport),
      isTrue,
      reason: 'page $index is off screen',
    );
  }
}

/// Finds a page that may be off screen but still mounted.
Finder mountedPage(int index) =>
    find.byKey(ValueKey('page-$index'), skipOffstage: false);

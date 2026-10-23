import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals.dart';
import 'package:yukari/controllers/multi_selection.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/selection/selection_chrome.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  late List<String> targets;
  late Signal<List<String>> selectable;
  late MultiSelection selection;
  late int shares;

  setUp(() {
    targets = ['a', 'b', 'c'];
    selectable = signal(targets);
    selection = MultiSelection(selectable: selectable);
    shares = 0;
    addTearDown(() {
      selection.dispose();
      selectable.dispose();
    });
  });

  /// Pumps the three pieces of chrome on one scaffold, as a page wears them.
  Future<void> pumpChrome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SelectionScope(
          selection: selection,
          child: Scaffold(
            appBar: SelectionAppBar(selection: selection),
            body: const SizedBox.shrink(),
            bottomNavigationBar: SelectionToolbar(
              selection: selection,
              onShare: () => shares++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The scope's pop guard.
  PopScope<Object?> popGuard(WidgetTester tester) =>
      tester.widget<PopScope<Object?>>(
        find.byWidgetPredicate((widget) => widget is PopScope<Object?>),
      );

  /// The share action in the docked toolbar.
  M3EButton shareButton(WidgetTester tester) => tester.widget<M3EButton>(
    find.ancestor(
      of: find.text(strings.selectionShare),
      matching: find.byType(M3EButton),
    ),
  );

  testWidgets('the check shows both states in one 24 dp box', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SelectionCheck(selected: true),
              SelectionCheck(selected: false),
            ],
          ),
        ),
      ),
    );

    final scheme = Theme.of(
      tester.element(find.byType(SelectionCheck).first),
    ).colorScheme;
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].icon, Icons.check_circle_rounded);
    expect(icons[0].color, scheme.primary);
    expect(icons[1].icon, Icons.circle_outlined);
    expect(icons[1].color, scheme.outlineVariant);
    for (final check in find.byType(SelectionCheck).evaluate()) {
      expect(tester.getSize(find.byWidget(check.widget)), const Size(24, 24));
    }
  });

  testWidgets('the bar counts what is selected', (tester) async {
    await pumpChrome(tester);
    expect(find.text(strings.selectionSelected(0)), findsOneWidget);

    selection.toggle('a');
    await tester.pumpAndSettle();

    expect(find.text(strings.selectionSelected(1)), findsOneWidget);
    expect(find.text(strings.selectionSelected(0)), findsNothing);

    selection.select(targets);
    await tester.pumpAndSettle();

    expect(find.text(strings.selectionSelected(3)), findsOneWidget);
  });

  testWidgets('close leaves selection', (tester) async {
    await pumpChrome(tester);
    selection
      ..enter()
      ..toggle('a');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(strings.selectionExit));
    await tester.pumpAndSettle();

    expect(selection.selecting.value, isFalse);
    expect(selection.ids.value, isEmpty);
  });

  testWidgets('select all fills the selection, then clears it', (tester) async {
    await pumpChrome(tester);
    selection.enter();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(strings.selectionSelectAll));
    await tester.pumpAndSettle();

    expect(selection.count.value, 3);
    expect(selection.allSelected.value, isTrue);
    // The action becomes its opposite once everything is in.
    expect(find.byTooltip(strings.selectionDeselectAll), findsOneWidget);

    await tester.tap(find.byTooltip(strings.selectionDeselectAll));
    await tester.pumpAndSettle();

    expect(selection.ids.value, isEmpty);
    expect(find.byTooltip(strings.selectionSelectAll), findsOneWidget);
  });

  testWidgets('the docked share action is disabled until something is in', (
    tester,
  ) async {
    await pumpChrome(tester);
    expect(shareButton(tester).onPressed, isNull);

    selection
      ..enter()
      ..toggle('b');
    await tester.pumpAndSettle();

    expect(shareButton(tester).onPressed, isNotNull);
    await tester.tap(find.text(strings.selectionShare));
    await tester.pumpAndSettle();

    expect(shares, 1);
  });

  testWidgets('the toolbar is the docked surface', (
    tester,
  ) async {
    await pumpChrome(tester);

    expect(find.byType(M3EDockedToolbar), findsOneWidget);
    expect(find.byType(M3EHorizontalFloatingToolbar), findsNothing);
    // 64 dp tall and edge to edge: the Gallery/Files bar.
    final size = tester.getSize(find.byType(M3EDockedToolbar));
    expect(size.height, 64);
    expect(size.width, tester.getSize(find.byType(Scaffold)).width);
  });

  testWidgets('Escape and back leave selection instead of the page', (
    tester,
  ) async {
    await pumpChrome(tester);
    selection.enter();
    await tester.pumpAndSettle();
    // Selection takes the keyboard focus, so Escape reaches the binding.
    expect(popGuard(tester).canPop, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selection.selecting.value, isFalse);

    selection.enter();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(selection.selecting.value, isFalse);
    expect(popGuard(tester).canPop, isTrue);
  });

  testWidgets('a target that stops being selectable stops counting', (
    tester,
  ) async {
    await pumpChrome(tester);
    selection.select(['a', 'b']);
    await tester.pumpAndSettle();
    expect(selection.count.value, 2);

    // The page filtered one out; nothing has to be pruned by hand.
    selectable.value = ['a', 'c'];
    await tester.pumpAndSettle();

    expect(selection.count.value, 1);
    expect(selection.orderedSelection, ['a']);
    expect(find.text(strings.selectionSelected(1)), findsOneWidget);
  });
}

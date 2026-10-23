import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart'
    show M3EReorderableSegmentedList, M3ESelectionMode;
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/instance.dart';
import 'package:yukari/widgets/network_card/network_card_data.dart';
import 'package:yukari/widgets/network_card/network_card.dart';
import 'package:yukari/widgets/network_card/network_card_list.dart';
import 'package:yukari/widgets/selection/selection_chrome.dart';

void main() {
  var deleted = 0;
  var exported = 0;
  var shared = 0;

  Future<void> pumpList(
    WidgetTester tester, {
    bool running = false,
    bool selecting = false,
    Set<int> selectedIndices = const {},
    ValueChanged<Set<int>>? onSelectionChanged,
    List<String> names = const ['Home'],
  }) async {
    deleted = 0;
    exported = 0;
    shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: NetworkCardList(
            networks: [
              for (final name in names)
                NetworkCardData(
                  id: name.toLowerCase(),
                  name: name,
                  status: running
                      ? InstanceStatus.running
                      : InstanceStatus.stopped,
                  running: running,
                  onOpen: () {},
                  onEdit: () {},
                  onShare: () => shared++,
                  onExport: () => exported++,
                  onLog: () {},
                  onDelete: () async => deleted++,
                  onToggle: (start) {},
                ),
            ],
            onReorder: (_, _) {},
            keyBuilder: ValueKey.new,
            selecting: selecting,
            selectedIndices: selectedIndices,
            onSelectionChanged: onSelectionChanged,
          ),
        ),
      ),
    );
  }

  // The menu takes focus when it opens, which must not rebuild the card and
  // so dismiss the menu it hosts.
  testWidgets('one tap on the overflow button opens the menu', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('one secondary click opens the menu', (tester) async {
    await pumpList(tester);
    await tester.tapAt(
      tester.getCenter(find.text('Home')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the menu exports the network, then closes', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(exported, 1);
    expect(find.text('Export'), findsNothing);
  });

  // Export reads the saved config, so it stays available where Edit and Log
  // are not.
  testWidgets('the menu exports a running network', (tester) async {
    await pumpList(tester, running: true);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(exported, 1);
  });

  testWidgets('the menu shares over QR, above Export', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byTooltip('More options for Home'));
    await tester.pumpAndSettle();

    expect(find.text('Share via QR'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Share via QR')).dy,
      lessThan(tester.getTopLeft(find.text('Export')).dy),
      reason: 'sharing sits directly before Export',
    );

    await tester.tap(find.text('Share via QR'));
    await tester.pumpAndSettle();

    expect(shared, 1);
    expect(find.text('Share via QR'), findsNothing);
  });

  /// The list widget, as the page configured it.
  M3EReorderableSegmentedList listOf(WidgetTester tester) => tester
      .widget<M3EReorderableSegmentedList>(
        find.byType(M3EReorderableSegmentedList),
      );

  testWidgets('a card that is not selecting stays a single selection', (
    tester,
  ) async {
    await pumpList(tester);

    final list = listOf(tester);
    expect(list.selectionMode, M3ESelectionMode.single);
    expect(list.showSelectionCheckmark, isFalse);
    expect(list.selectedIndices, isEmpty);
    // The card keeps the controls it acts with.
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(SelectionCheck), findsNothing);
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('selecting turns each row into its name and the check', (
    tester,
  ) async {
    final changes = <Set<int>>[];
    await pumpList(
      tester,
      selecting: true,
      selectedIndices: const {0},
      onSelectionChanged: changes.add,
      names: ['Home', 'Office'],
    );

    final list = listOf(tester);
    expect(list.selectionMode, M3ESelectionMode.multiple);
    expect(list.selectedIndices, {0});
    expect(list.showSelectionCheckmark, isFalse);

    // The row is its name and the check: no status badge, no start/stop
    // button, no menu.
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
    expect(find.byTooltip('More options for Home'), findsNothing);
    expect(find.byType(SelectionCheck), findsNWidgets(2));

    final checks = tester
        .widgetList<SelectionCheck>(find.byType(SelectionCheck))
        .toList();
    expect(checks[0].selected, isTrue);
    expect(checks[1].selected, isFalse);
    expect(
      tester.getCenter(find.byType(SelectionCheck).first).dy,
      closeTo(tester.getCenter(find.byType(NetworkCard).first).dy, 0.5),
      reason: 'the check is centred on the row',
    );

    // A tap selects the row: no start/stop, no menu.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(changes, [<int>{}], reason: 'the selected row is taken back out');
  });
}

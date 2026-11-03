import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/link_list/link_list.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<LinkListEntry> entries) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 360, child: LinkList(entries: entries)),
            ),
          ),
        ),
      );

  testWidgets('shows every link with its icon and chevron', (tester) async {
    await pump(tester, [
      LinkListEntry(
        icon: const Icon(Icons.article_outlined),
        label: 'Logs',
        onTap: () {},
      ),
      LinkListEntry(
        icon: const Icon(Icons.info_outline),
        label: 'About',
        onTap: () {},
      ),
    ]);

    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('runs a link from anywhere on its row', (tester) async {
    var taps = 0;
    await pump(tester, [
      LinkListEntry(
        icon: const Icon(Icons.article_outlined),
        label: 'Logs',
        onTap: () => taps++,
      ),
    ]);

    final row = tester.getRect(find.text('Logs'));
    // The label itself, and the row's trailing edge away from the label.
    await tester.tapAt(row.center);
    await tester.pump();
    expect(taps, 1);

    await tester.tapAt(Offset(row.right + 120, row.center.dy));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('lays the rows out as one segmented group', (tester) async {
    await pump(tester, [
      LinkListEntry(
        icon: const Icon(Icons.article_outlined),
        label: 'Logs',
        onTap: () {},
      ),
      LinkListEntry(
        icon: const Icon(Icons.info_outline),
        label: 'About',
        onTap: () {},
      ),
    ]);

    expect(find.byType(LinkList), findsOneWidget);
    // Both rows share one column, one under the other.
    final logs = tester.getRect(find.text('Logs'));
    final about = tester.getRect(find.text('About'));
    expect(about.top, greaterThan(logs.bottom));
    expect(about.left, logs.left);
  });
}

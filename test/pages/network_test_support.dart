import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/signals/bookmarks.dart' as bookmarks;
import 'package:yukari/signals/networks.dart' as saved;

import '../networks_fixture.dart';

/// Keeps focused text fields from blinking their cursor, which would schedule
/// frames forever and never let `pumpAndSettle` settle.
void useDeterministicCursor() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);
}

/// The English strings the page tests assert against.
final strings = lookupAppLocalizations(const Locale('en'));

/// Pumps [home] with the app's localizations, as the router would.
///
/// [settle] waits for every animation; a page that keeps one running (the
/// editor beside the list) is pumped a bounded number of frames instead.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs a store-writing [interaction] outside the fake clock, then waits for
/// both stores.
///
/// File IO started under the fake clock never completes, which leaves the test
/// hanging when it ends, so every interaction that saves runs in the real zone.
Future<void> saving(
  WidgetTester tester,
  Future<void> Function() interaction,
) async {
  await tester.runAsync(() async {
    await interaction();
    await Future.wait([saved.settled(), bookmarks.settled()]);
  });
  await tester.pumpAndSettle();
}

/// The text field labelled [label].
Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Taps the tab named [label].
Future<void> switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Expands the collapsed section titled [title].
Future<void> expandSection(WidgetTester tester, String title) =>
    tapVisible(tester, find.text(title).first);

/// Scrolls [finder] into view, then taps it and waits for the stores.
Future<void> tapSaving(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await saving(tester, () => tester.tap(finder));
}

/// Scrolls the field labelled [label] into view, then types [text] into it.
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final finder = field(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await saving(tester, () => tester.enterText(finder, text));
}

/// Seeds the saved networks signal with [networks] from a fresh store.
Future<void> seedWith(Map<String, Network> networks) async {
  final store = temporaryStore();
  await store.save(networks);
  await saved.init(store);
  addTearDown(saved.dispose);
}

/// A network with every field the editor can show, at its default.
Network seededNetwork({
  String name = 'alpha',
  String? hostname,
  bool dhcp = true,
  String? ipv4,
  List<Node> nodes = const [],
  List<Uri> listeners = const [],
  List<ProxyNetwork> proxyNetworks = const [],
  NetworkFlags? flags,
}) => Network()
  ..networkName = name
  ..hostname = hostname
  ..dhcp = dhcp
  ..ipv4 = ipv4
  ..nodes = [...nodes]
  ..listeners = [...listeners]
  ..proxyNetworks = [...proxyNetworks]
  ..flags = flags ?? NetworkFlags();

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:yukari/pages/networks/editor_exit_guard.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/widgets/network_card/network_card.dart';

import '../router_support.dart';
import 'network_detail_support.dart';
import 'network_test_support.dart' hide pumpApp;

/// Opens the editor from the list through the app's own router, and reports the
/// card it grew out of.
Future<Rect> openEditor(WidgetTester tester, {bool dirty = false}) async {
  await pumpApp(tester, size: realRouterWindow);
  final card = tester.getRect(find.byType(NetworkCard).first);
  await tester.tap(find.text('alpha'));
  await tester.pumpAndSettle();
  expect(find.byType(NetworkEditorPage), findsOneWidget);
  if (!dirty) return card;
  await tester.enterText(field(strings.networkName), '');
  await tester.pumpAndSettle();
  expect(hasInvalidInput(editorGuardKey('n1')), isTrue);
  return card;
}

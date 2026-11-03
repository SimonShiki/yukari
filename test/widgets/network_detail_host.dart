import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/widgets/network_card/network_detail_route.dart';

import 'network_detail_harness.dart';

/// Pushes a detail route out of [origin] and leaves the push mid-flight.
Future<void> openPage(
  WidgetTester tester, {
  required Rect? origin,
  bool canPop = true,
}) async {
  useWindow(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                NetworkDetailRoute(
                  origin: origin,
                  builder: (context) => PopScope(
                    canPop: canPop,
                    child: Scaffold(
                      appBar: AppBar(title: const Text('detail')),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
}

/// Pushes a detail route out of [origin] and settles the push.
Future<void> pumpRoute(
  WidgetTester tester, {
  required Rect? origin,
  bool canPop = true,
}) async {
  await openPage(tester, origin: origin, canPop: canPop);
  await tester.pumpAndSettle();
}

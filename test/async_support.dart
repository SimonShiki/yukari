import 'package:flutter_test/flutter_test.dart';

/// Yields to the event loop until [condition] holds, up to a bounded number of
/// turns.
Future<void> waitFor(bool Function() condition) async {
  for (var turn = 0; turn < 1000; turn++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'the condition did not settle');
}

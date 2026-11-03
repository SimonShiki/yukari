import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Polls [condition] until it holds, or fails the test once [timeout] passes.
///
/// [condition] may be asynchronous, so a condition whose answer takes real
/// work, such as reading an instance that reports running once it is up, gets
/// the time it needs instead of one instant's answer.
Future<void> waitFor(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final elapsed = Stopwatch()..start();
  while (!await condition()) {
    if (elapsed.elapsed >= timeout) {
      expect(await condition(), isTrue, reason: 'the condition did not settle');
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/network_page_controller.dart';

void main() {
  test('disposing during a create writes no disposed signal', () async {
    final gate = Completer<void>();
    final navigated = <String>[];
    final messages = <String>[];
    final controller = NetworkCreatorController(
      navigate: navigated.add,
      showMessage: messages.add,
      add: (_, _) => gate.future,
    );

    final creating = controller.create(name: 'fresh');
    expect(controller.creating.value, isTrue);
    controller.dispose();
    gate.complete();

    await expectLater(creating, completes);
    expect(
      controller.creating.peek(),
      isTrue,
      reason: 'the flag is not cleared after dispose',
    );
    expect(navigated, isEmpty);
    expect(messages, isEmpty);
  });

  test('a create that fails after dispose is not reported', () async {
    final gate = Completer<void>();
    final messages = <String>[];
    final controller = NetworkCreatorController(
      navigate: (_) {},
      showMessage: messages.add,
      add: (_, _) async {
        await gate.future;
        throw StateError('disk');
      },
    );

    final creating = controller.create(name: 'fresh');
    controller.dispose();
    gate.complete();

    await expectLater(creating, completes);
    expect(
      controller.creating.peek(),
      isTrue,
      reason: 'the failure path is not written after dispose',
    );
    expect(messages, isEmpty);
  });
}

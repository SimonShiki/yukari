import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari/utils/optimistic_store.dart';

void main() {
  test(
    'a pending write publishes immediately and holds subsequent mutations',
    () async {
      final queue = MutationQueue();
      final state = signal('saved');
      addTearDown(state.dispose);
      final started = Completer<void>();
      final save = Completer<void>();
      final seen = <String>[];
      final first = queue.enqueue(
        () => persistOptimistically(state, 'first', (value) async {
          seen.add(value);
          started.complete();
          await save.future;
        }),
      );
      final second = queue.enqueue(() async {
        expect(state.peek(), 'first');
        await persistOptimistically(
          state,
          'second',
          (value) async => seen.add(value),
        );
        return 2;
      });
      var settled = false;
      final waiting = queue.settled().then((_) => settled = true);

      await started.future;
      expect(state.peek(), 'first');
      expect(seen, ['first']);
      expect(settled, isFalse);
      save.complete();
      await first;
      expect(await second, 2);
      await waiting;
      expect(settled, isTrue);
      expect(seen, ['first', 'second']);
      expect(state.peek(), 'second');
    },
  );

  test('a failed write rolls back before the next mutation runs', () async {
    final queue = MutationQueue();
    final state = signal('saved');
    addTearDown(state.dispose);
    final save = Completer<void>();
    final started = Completer<void>();
    final error = StateError('disk full');
    final seen = <String>[];
    addTearDown(effect(() => seen.add(state.value)));
    final first = queue.enqueue(
      () => persistOptimistically(state, 'draft', (_) {
        started.complete();
        return save.future;
      }),
    );
    final failure = expectLater(first, throwsA(same(error)));
    final second = queue.enqueue(() async {
      expect(state.peek(), 'saved');
      await persistOptimistically(state, 'next', (_) async {});
    });

    await started.future;
    expect(state.peek(), 'draft');
    save.completeError(error);
    await failure;
    await second;
    await queue.settled();

    expect(seen, ['saved', 'draft', 'saved', 'next']);
    expect(state.peek(), 'next');
  });

  test('a synchronous mutation error does not poison the queue', () async {
    final queue = MutationQueue();
    final failed = queue.enqueue<int>(() => throw StateError('invalid input'));
    final failure = expectLater(failed, throwsStateError);
    final next = queue.enqueue(() async => 42);

    await failure;
    expect(await next, 42);
    await expectLater(queue.settled(), completes);
  });
}

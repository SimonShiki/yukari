import 'package:signals/signals.dart';

/// Serializes store mutations without letting one failure block later work.
final class MutationQueue {
  Future<void> _tail = Future.value();

  /// Runs [operation] after earlier mutations, preserving its result or error.
  Future<T> enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Completes after the currently queued mutations, including failed ones.
  Future<void> settled() => _tail;
}

/// Publishes [next] to [state], then saves it with [persist]. Restores the
/// previous value and rethrows if saving fails. Call within a mutation queue.
Future<void> persistOptimistically<T>(
  Signal<T> state,
  T next,
  Future<void> Function(T) persist,
) async {
  final previous = state.peek();
  state.value = next;
  try {
    await persist(next);
  } catch (_) {
    state.value = previous;
    rethrow;
  }
}

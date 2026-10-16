import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/ffi_backend.dart';

void main() {
  test('disposing an in-process backend disposes its status signal', () async {
    final backend = FfiBackend();
    expect(backend.status.disposed, isFalse);

    await backend.dispose();

    expect(backend.status.disposed, isTrue);
  });

  test('a stop that throws still disposes the status signal', () async {
    final backend = _RefusingStopBackend();
    expect(backend.status.disposed, isFalse);

    await expectLater(backend.dispose(), throwsStateError);

    expect(backend.status.disposed, isTrue);
  });
}

/// A backend whose stop always fails: the disposal must release the status
/// signal anyway, as `switchBackend` has already dropped this backend.
class _RefusingStopBackend extends FfiBackend {
  @override
  Future<void> stop(List<String> names) async => throw StateError('refused');
}

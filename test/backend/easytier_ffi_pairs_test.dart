import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/bindings/easytier_ffi_native.dart';
import 'package:yukari_core/bindings/generated/easytier.g.dart' as native;

/// A list-style call over [count] pairs that clamps its answer to the
/// capacity, the way EasyTier's does; [calls] records each capacity asked.
int Function(Pointer<native.KeyValuePair>, int) clampingList(
  int count,
  List<int> calls,
) {
  final strings = <Pointer<Utf8>>[];
  addTearDown(() => strings.forEach(calloc.free));
  Pointer<Char> owned(String value) {
    final pointer = value.toNativeUtf8(allocator: calloc);
    strings.add(pointer);
    return pointer.cast();
  }

  return (pairs, capacity) {
    calls.add(capacity);
    final written = count < capacity ? count : capacity;
    for (var i = 0; i < written; i++) {
      pairs[i]
        ..key = owned('network-$i')
        ..value = owned('{"id":$i}');
    }
    return written;
  };
}

void main() {
  test('reads every pair when they fit the first buffer', () {
    final calls = <int>[];

    final pairs = readPairs(clampingList(3, calls), 'list_instance');

    expect(pairs, {
      'network-0': '{"id":0}',
      'network-1': '{"id":1}',
      'network-2': '{"id":2}',
    });
    expect(calls, [16]);
  });

  test('grows past a full buffer instead of dropping pairs', () {
    final calls = <int>[];

    final pairs = readPairs(clampingList(40, calls), 'list_instance');

    expect(pairs, hasLength(40));
    expect(pairs['network-39'], '{"id":39}');
    expect(calls, [16, 32, 64]);
  });

  test('a count that exactly fills a buffer is confirmed by a larger one', () {
    final calls = <int>[];

    final pairs = readPairs(clampingList(16, calls), 'list_instance');

    expect(pairs, hasLength(16));
    expect(calls, [16, 32]);
  });
}

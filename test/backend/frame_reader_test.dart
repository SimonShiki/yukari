import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/backend/ipc/ipc_channel.dart';

void main() {
  test('decodes Unicode and adjacent frames at every split boundary', () {
    final messages = <Object?>[
      {'text': '雪🌸'},
      null,
      [1, true],
    ];
    final bytes = Uint8List.fromList([
      for (final message in messages) ...encodeFrame(message),
    ]);
    for (var split = 0; split <= bytes.length; split++) {
      final reader = FrameReader(maxLength: 64);
      expect(
        [
          ...reader.add(Uint8List.sublistView(bytes, 0, split)),
          ...reader.add([]),
          ...reader.add(Uint8List.sublistView(bytes, split)),
        ],
        messages,
        reason: 'split at $split',
      );
    }
  });

  test('reassembles a maximum size frame delivered in small chunks', () {
    final message = 'x' * (maxFrameLength - 2);
    final bytes = encodeFrame(message);
    final reader = FrameReader(maxLength: maxFrameLength);
    final messages = <Object?>[];
    for (var start = 0; start < bytes.length; start += 1024) {
      final end = start + 1024 < bytes.length ? start + 1024 : bytes.length;
      messages.addAll(reader.add(Uint8List.sublistView(bytes, start, end)));
    }
    expect(messages, [message]);
    expect(reader.add(encodeFrame(true)), [true]);
  });

  test('snapshots incomplete input before the caller reuses its buffer', () {
    final bytes = encodeFrame({'text': 'unchanged'});
    final chunk = Uint8List.fromList(bytes.sublist(0, bytes.length - 1));
    final reader = FrameReader(maxLength: 64);
    expect(reader.add(chunk), isEmpty);
    chunk.fillRange(0, chunk.length, 0);
    expect(reader.add(bytes.sublist(bytes.length - 1)), [
      {'text': 'unchanged'},
    ]);
  });

  test('rejects an oversized split header as soon as it is complete', () {
    final header = ByteData(4)..setUint32(0, helloFrameLength + 1);
    final bytes = header.buffer.asUint8List();
    final reader = FrameReader(maxLength: helloFrameLength);
    for (var i = 0; i < 3; i++) {
      expect(reader.add([bytes[i]]), isEmpty);
    }
    expect(() => reader.add([bytes[3]]), throwsFormatException);
  });

  test('uses the authenticated limit for subsequent frames', () {
    final reader = FrameReader(maxLength: helloFrameLength);
    expect(reader.add(encodeFrame({'hello': true})), [
      {'hello': true},
    ]);
    reader.maxLength = maxFrameLength;
    final message = 'x' * helloFrameLength;
    expect(reader.add(encodeFrame(message)), [message]);
  });

  test('rechecks a lowered limit before buffering another body chunk', () {
    final bytes = encodeFrame('x' * helloFrameLength);
    final reader = FrameReader(maxLength: maxFrameLength);
    expect(reader.add(bytes.sublist(0, 10)), isEmpty);
    reader.maxLength = helloFrameLength;
    expect(() => reader.add(bytes.sublist(10)), throwsFormatException);
  });

  test('rejects empty, malformed JSON and invalid UTF-8 bodies', () {
    for (final body in <List<int>>[
      [],
      utf8.encode('{'),
      [0xff],
    ]) {
      final header = ByteData(4)..setUint32(0, body.length);
      final reader = FrameReader(maxLength: 64);
      expect(
        () => reader.add([...header.buffer.asUint8List(), ...body]),
        throwsFormatException,
      );
    }
  });
}

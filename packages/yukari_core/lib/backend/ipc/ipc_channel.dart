import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

/// Upper bound of a frame from an authenticated peer.
const maxFrameLength = 16 << 20;

/// Upper bound of a frame before the peer said hello.
const helloFrameLength = 4 << 10;

/// JSON-RPC error code for peers that did not authenticate.
const accessDenied = -32001;

/// Decoded JSON messages over [socket], for `json_rpc_2`'s `withoutJson`
/// peers. Each message is framed as a 4-byte big-endian length followed by
/// UTF-8 JSON.
///
/// A frame over [reader]'s limit drops the connection, so a peer can never
/// make the other side buffer without bound.
StreamChannel<Object?> frameChannel(Socket socket, FrameReader reader) {
  final outgoing = StreamController<Object?>();
  outgoing.stream.map<List<int>>(encodeFrame).pipe(socket).catchError((
    Object _,
  ) {
    socket.destroy();
  });
  final incoming = socket.transform(
    StreamTransformer<Uint8List, Object?>.fromHandlers(
      handleData: (chunk, sink) {
        try {
          reader.add(chunk).forEach(sink.add);
        } on FormatException {
          socket.destroy();
        }
      },
    ),
  );
  return StreamChannel(incoming, outgoing.sink);
}

Uint8List encodeFrame(Object? message) {
  final body = utf8.encode(jsonEncode(message));
  final header = ByteData(4)..setUint32(0, body.length);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(body))
      .takeBytes();
}

/// Reassembles frames from the chunks a socket delivers.
final class FrameReader {
  FrameReader({required this.maxLength});

  /// Longest accepted frame; longer ones fail with [FormatException].
  int maxLength;

  final _header = ByteData(4);
  var _headerLength = 0;
  int? _length;
  final _body = BytesBuilder(copy: false);

  /// Adds [chunk] and returns the messages of the frames it completed.
  List<Object?> add(List<int> chunk) {
    final messages = <Object?>[];
    var offset = 0;
    while (offset < chunk.length) {
      if (_length == null) {
        while (_headerLength < 4 && offset < chunk.length) {
          _header.setUint8(_headerLength++, chunk[offset++]);
        }
        if (_headerLength < 4) break;
        _length = _header.getUint32(0);
        _headerLength = 0;
      }
      final length = _length!;
      if (length > maxLength) {
        throw FormatException('IPC frame of $length bytes is too large');
      }
      final remaining = length - _body.length;
      final end = offset + remaining < chunk.length
          ? offset + remaining
          : chunk.length;
      if (end > offset) _body.add(chunk.sublist(offset, end));
      offset = end;
      if (_body.length < length) break;
      final body = _body.takeBytes();
      _length = null;
      messages.add(jsonDecode(utf8.decode(body)));
    }
    return messages;
  }
}

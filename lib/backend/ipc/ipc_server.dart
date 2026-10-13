import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart';

import 'ipc_channel.dart';

/// A JSON-RPC method of the service.
typedef IpcMethod = FutureOr<Object?> Function(Parameters params);

/// The service's side of the IPC: serves [methods] over JSON-RPC 2.0 to
/// peers that first call `hello` with [token].
///
/// Until then every call fails with [accessDenied], frames are limited to
/// [helloFrameLength], and peers that take longer than [helloTimeout] are
/// dropped.
final class IpcServer {
  IpcServer(
    this._server, {
    required this.methods,
    this.token,
    this.helloTimeout = const Duration(seconds: 5),
  }) {
    _server.listen(_serve);
  }

  final ServerSocket _server;
  final Map<String, IpcMethod> methods;

  /// The secret peers must present, or null when the transport itself
  /// restricts access.
  final String? token;
  final Duration helloTimeout;
  final _peers = <Socket>{};

  Future<void> close() async {
    await _server.close();
    for (final peer in _peers.toList()) {
      peer.destroy();
    }
  }

  void _serve(Socket socket) {
    final reader = FrameReader(maxLength: helloFrameLength);
    final server = Server.withoutJson(frameChannel(socket, reader));
    final hello = Timer(helloTimeout, socket.destroy);
    var authenticated = false;

    server.registerMethod('hello', (Parameters params) {
      if (!_accepts(params['token'].valueOr(null))) {
        throw RpcException(accessDenied, 'Access denied');
      }
      hello.cancel();
      authenticated = true;
      reader.maxLength = maxFrameLength;
    });
    for (final MapEntry(key: name, value: method) in methods.entries) {
      server.registerMethod(name, (Parameters params) {
        if (!authenticated) throw RpcException(accessDenied, 'Access denied');
        return method(params);
      });
    }

    _peers.add(socket);
    server.listen().whenComplete(() {
      hello.cancel();
      _peers.remove(socket);
      socket.destroy();
    }).ignore();
  }

  bool _accepts(Object? presented) {
    final expected = token;
    if (expected == null) return true;
    if (presented is! String) return false;
    // Compare in constant time so the token cannot be guessed bytewise.
    final a = utf8.encode(expected), b = utf8.encode(presented);
    var difference = a.length ^ b.length;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ (i < b.length ? b[i] : 0);
    }
    return difference == 0;
  }
}

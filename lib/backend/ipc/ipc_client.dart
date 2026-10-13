import 'dart:async';
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart';

import 'ipc_channel.dart';
import 'ipc_endpoint.dart';

/// Connects to the service at [endpoint] and says hello, which fails with
/// an [RpcException] when the service rejects the token.
Future<Client> connectIpc(
  IpcEndpoint endpoint, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final socket = await Socket.connect(
    endpoint.address,
    endpoint.port,
    timeout: timeout,
  );
  final client = Client.withoutJson(
    frameChannel(socket, FrameReader(maxLength: maxFrameLength)),
  );
  unawaited(client.listen());
  try {
    await client.sendRequest('hello', {'token': endpoint.token}).timeout(timeout);
    return client;
  } catch (_) {
    await client.close();
    rethrow;
  }
}

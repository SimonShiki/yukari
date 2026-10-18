import 'dart:async';
import 'dart:io';

import 'package:json_rpc_2/error_code.dart' as error_code;
import 'package:json_rpc_2/json_rpc_2.dart';

import 'package:yukari_core/backend/ipc/ipc_channel.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';

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
    await client
        .sendRequest('hello', {'token': endpoint.token})
        .timeout(timeout);
    return client;
  } catch (_) {
    await client.close();
    rethrow;
  }
}

/// The version the service at [endpoint] runs, or null when it cannot be
/// reached; see `serviceVersion`.
Future<int?> runningServiceVersion(IpcEndpoint endpoint) async {
  final Client client;
  try {
    client = await connectIpc(endpoint);
  } catch (_) {
    return null;
  }
  try {
    return await client.sendRequest('version') as int;
  } on RpcException catch (error) {
    // Services from before versions existed lack the method.
    if (error.code == error_code.METHOD_NOT_FOUND) return 0;
    rethrow;
  } finally {
    await client.close();
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_rpc_2/error_code.dart' as error_code;
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:yukari_core/backend/ipc/ipc_channel.dart';
import 'package:yukari/backend/ipc/ipc_client.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari_core/backend/ipc/ipc_server.dart';

void main() {
  group('FrameReader', () {
    test('reassembles frames split across chunks', () {
      final bytes = [
        ...encodeFrame({'id': 1}),
        ...encodeFrame({'id': 2}),
      ];
      final reader = FrameReader(maxLength: 64);
      expect(reader.add(bytes.sublist(0, 3)), isEmpty);
      expect(reader.add(bytes.sublist(3, 12)), [
        {'id': 1},
      ]);
      expect(reader.add(bytes.sublist(12)), [
        {'id': 2},
      ]);
    });

    test('rejects frames over the limit before buffering them', () {
      final header = ByteData(4)..setUint32(0, 1 << 30);
      expect(
        () => FrameReader(maxLength: 64).add(header.buffer.asUint8List()),
        throwsFormatException,
      );
    });
  });

  group('IpcServer', () {
    late IpcEndpoint endpoint;

    setUp(() async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final server = IpcServer(
        socket,
        token: 'secret',
        helloTimeout: const Duration(milliseconds: 200),
        methods: {'echo': (params) => params.value},
      );
      endpoint = IpcEndpoint(socket.address, socket.port, token: 'secret');
      addTearDown(server.close);
    });

    Matcher rpcError(int code) =>
        throwsA(isA<RpcException>().having((e) => e.code, 'code', code));

    test('answers peers that present the token', () async {
      final client = await connectIpc(endpoint);
      addTearDown(client.close);
      expect(await client.sendRequest('echo', {'a': 1}), {'a': 1});
      await expectLater(
        client.sendRequest('missing'),
        rpcError(error_code.METHOD_NOT_FOUND),
      );
    });

    test('turns away peers with the wrong token', () async {
      final wrong = IpcEndpoint(endpoint.address, endpoint.port, token: 'x');
      await expectLater(connectIpc(wrong), rpcError(accessDenied));
    });

    test('denies calls before hello, then drops the peer', () async {
      final socket = await Socket.connect(endpoint.address, endpoint.port);
      final client = Client.withoutJson(
        frameChannel(socket, FrameReader(maxLength: maxFrameLength)),
      );
      final done = client.listen();
      await expectLater(client.sendRequest('echo', {}), rpcError(accessDenied));
      await done.timeout(const Duration(seconds: 2));
      expect(client.isClosed, isTrue);
    });
  });
}

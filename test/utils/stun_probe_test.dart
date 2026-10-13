import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/peer.dart';
import 'package:yukari/utils/stun_probe.dart';

/// A STUN server on loopback that reports the client's address, with its
/// port shifted by [portOffset] as a symmetric NAT would.
Future<RawDatagramSocket> _server({int portOffset = 0}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(socket.close);
  socket.listen((event) {
    final request = socket.receive();
    if (request == null) return;
    final port = (request.port + portOffset) ^ 0x2112;
    final address = request.address.rawAddress;
    final response = BytesBuilder()
      ..add([0x01, 0x01, 0x00, 12])
      ..add(request.data.sublist(4, 20))
      ..add([0x00, 0x20, 0x00, 8, 0x00, 0x01, port >> 8, port & 0xff])
      ..add([
        address[0] ^ 0x21,
        address[1] ^ 0x12,
        address[2] ^ 0xA4,
        address[3] ^ 0x42,
      ]);
    socket.send(response.takeBytes(), request.address, request.port);
  });
  return socket;
}

void main() {
  test('reports the mapped address of a cone NAT', () async {
    final a = await _server();
    final b = await _server();

    final probe = await probeNat(
      servers: [('127.0.0.1', a.port), ('127.0.0.1', b.port)],
    );

    expect(probe.publicAddress, '127.0.0.1');
    // Neither server can answer from elsewhere to test filtering.
    expect(probe.natType, NatType.restricted);
  });

  test('tells symmetric NATs apart by their mapped ports', () async {
    final a = await _server();
    final b = await _server(portOffset: 500);

    final probe = await probeNat(
      servers: [('127.0.0.1', a.port), ('127.0.0.1', b.port)],
    );

    expect(probe.natType, NatType.symmetric);
  });

  test('finds no address when no server answers', () async {
    final silent = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(silent.close);

    final probe = await probeNat(servers: [('127.0.0.1', silent.port)]);

    expect(probe.publicAddress, isNull);
    expect(probe.natType, NatType.unknown);
  });
}

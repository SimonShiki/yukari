import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/peer.dart';

/// What STUN servers saw of this device: its public IPv4 address, and how
/// its NAT maps and filters UDP.
final class NatProbe {
  const NatProbe({required this.publicAddress, required this.natType});

  /// Null when no server answered, as when UDP is blocked.
  final String? publicAddress;
  final NatType natType;
}

/// Servers to query in order. The first supports RFC 5780's CHANGE-REQUEST,
/// which tells cone NATs apart; the rest only report mapped addresses.
const defaultStunServers = [
  ('stun.stunprotocol.org', 3478),
  ('stun.miwifi.com', 3478),
  ('stun.chat.bilibili.com', 3478),
  ('stun.cloudflare.com', 3478),
  ('stun.l.google.com', 19302),
];

/// Classifies the NAT like RFC 3489 does, from one UDP socket: the mapping
/// is symmetric when servers see different ports, and filtering is tested
/// with replies from another address or port.
Future<NatProbe> probeNat({
  List<(String, int)> servers = defaultStunServers,
}) async {
  final socket = await _StunSocket.bind();
  try {
    final responses = <_Response>[];
    for (final (host, port) in servers) {
      final address = await _lookup(host);
      if (address == null) continue;
      if (await socket.request(address, port) case final response?) {
        responses.add(response);
        if (responses.length == 3) break;
      }
    }
    if (responses.isEmpty) {
      return const NatProbe(publicAddress: null, natType: NatType.unknown);
    }
    final mapped = responses.first.mapped;
    return NatProbe(
      publicAddress: mapped.address.address,
      natType: await _classify(socket, responses),
    );
  } finally {
    socket.close();
  }
}

Future<NatType> _classify(_StunSocket socket, List<_Response> responses) async {
  final mapped = responses.first.mapped;
  final ports = [for (final response in responses) response.mapped.port];
  final local = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final untranslated = local.any(
    (interface) => interface.addresses.contains(mapped.address),
  );

  if (responses.any((response) => response.mapped != mapped)) {
    final deltas = [
      for (var i = 1; i < ports.length; i++) ports[i] - ports[i - 1],
    ];
    if (deltas.every((delta) => delta > 0 && delta <= 20)) {
      return NatType.symmetricEasyIncrement;
    }
    if (deltas.every((delta) => delta < 0 && delta >= -20)) {
      return NatType.symmetricEasyDecrement;
    }
    return untranslated ? NatType.symmetricUdpFirewall : NatType.symmetric;
  }

  // Filtering tests need a server that can answer from elsewhere; without
  // one, assume restricted filtering as EasyTier does.
  final changing = responses
      .where((response) => response.canChange)
      .firstOrNull;
  if (changing == null) {
    return untranslated ? NatType.noPat : NatType.restricted;
  }
  final (server, port) = changing.server;
  if (await socket.request(server, port, change: _changeIp | _changePort)
      case _?) {
    return untranslated ? NatType.openInternet : NatType.fullCone;
  }
  if (untranslated) return NatType.noPat;
  if (await socket.request(server, port, change: _changePort) case _?) {
    return NatType.restricted;
  }
  return NatType.portRestricted;
}

Future<InternetAddress?> _lookup(String host) async {
  try {
    final addresses = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    );
    return addresses.firstOrNull;
  } on SocketException {
    return null;
  }
}

const _magicCookie = 0x2112A442;
const _changeIp = 0x04;
const _changePort = 0x02;

typedef _Endpoint = ({InternetAddress address, int port});

final class _Response {
  _Response(this.server, this.mapped, this.canChange);

  final (InternetAddress, int) server;
  final _Endpoint mapped;

  /// Whether the server has another address to answer CHANGE-REQUESTs from.
  final bool canChange;
}

/// One UDP socket that sends STUN binding requests (RFC 5389) and matches
/// the responses to them by transaction id, whatever address they come from.
final class _StunSocket {
  _StunSocket._(this._socket) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null || datagram.data.length < 20) return;
      final data = ByteData.sublistView(datagram.data);
      if (data.getUint16(0) != 0x0101 || data.getUint32(4) != _magicCookie) {
        return;
      }
      final id = _hex(datagram.data.sublist(8, 20));
      _pending.remove(id)?.complete(datagram.data);
    });
  }

  static Future<_StunSocket> bind() async =>
      _StunSocket._(await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0));

  final RawDatagramSocket _socket;
  final _pending = <String, Completer<Uint8List>>{};
  final _random = Random.secure();

  /// Sends a request twice before giving up after [timeout].
  Future<_Response?> request(
    InternetAddress server,
    int port, {
    int change = 0,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final id = Uint8List.fromList([
      for (var i = 0; i < 12; i++) _random.nextInt(256),
    ]);
    final message = BytesBuilder()
      ..add(_uint16(0x0001))
      ..add(_uint16(change == 0 ? 0 : 8))
      ..add(_uint32(_magicCookie))
      ..add(id);
    if (change != 0) {
      message
        ..add(_uint16(0x0003))
        ..add(_uint16(4))
        ..add(_uint32(change));
    }
    final bytes = message.takeBytes();
    final reply = Completer<Uint8List>();
    _pending[_hex(id)] = reply;
    _socket.send(bytes, server, port);
    final resend = Timer(timeout ~/ 3, () => _socket.send(bytes, server, port));
    try {
      final data = await reply.future.timeout(timeout);
      return _parse(data, (server, port));
    } on TimeoutException {
      return null;
    } finally {
      resend.cancel();
      _pending.remove(_hex(id));
    }
  }

  void close() => _socket.close();
}

_Response? _parse(Uint8List bytes, (InternetAddress, int) server) {
  final data = ByteData.sublistView(bytes);
  final end = min(bytes.length, 20 + data.getUint16(2));
  _Endpoint? mapped, xorMapped;
  var canChange = false;
  for (var offset = 20; offset + 4 <= end;) {
    final type = data.getUint16(offset);
    final length = data.getUint16(offset + 2);
    final value = offset + 4;
    if (value + length > end) break;
    // IPv4 address attributes: reserved, family 1, port, then the address.
    if (length >= 8 && data.getUint8(value + 1) == 1) {
      final port = data.getUint16(value + 2);
      final address = data.getUint32(value + 4);
      switch (type) {
        case 0x0001:
          mapped = (address: _ipv4(address), port: port);
        case 0x0020:
          xorMapped = (
            address: _ipv4(address ^ _magicCookie),
            port: port ^ (_magicCookie >> 16),
          );
        // CHANGED-ADDRESS (RFC 3489) and OTHER-ADDRESS (RFC 5780).
        case 0x0005 || 0x802C:
          canChange = true;
      }
    }
    offset = value + (length + 3) ~/ 4 * 4;
  }
  final endpoint = xorMapped ?? mapped;
  return endpoint == null ? null : _Response(server, endpoint, canChange);
}

InternetAddress _ipv4(int value) => InternetAddress.fromRawAddress(
  Uint8List.fromList(
    [24, 16, 8, 0].map((shift) => value >> shift & 0xff).toList(),
  ),
);

Uint8List _uint16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value);

Uint8List _uint32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value);

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

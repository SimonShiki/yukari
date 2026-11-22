import 'dart:typed_data';

Uint8List udpPacket({
  int source = 0xc0a80107,
  int destination = 0xffffffff,
  List<int> options = const [],
  List<int> payload = const [1, 2, 3],
}) {
  final ihl = 20 + options.length;
  final packet = Uint8List(ihl + 8 + payload.length);
  ByteData.sublistView(packet)
    ..setUint8(0, 0x40 | (ihl ~/ 4))
    ..setUint16(2, packet.length)
    ..setUint8(8, 64)
    ..setUint8(9, 17)
    ..setUint16(10, 0x1234)
    ..setUint32(12, source)
    ..setUint32(16, destination)
    ..setUint16(ihl, 12345)
    ..setUint16(ihl + 2, 37020)
    ..setUint16(ihl + 4, 8 + payload.length)
    ..setUint16(ihl + 6, 0xabcd);
  packet.setAll(20, options);
  packet.setAll(ihl + 8, payload);
  return packet;
}

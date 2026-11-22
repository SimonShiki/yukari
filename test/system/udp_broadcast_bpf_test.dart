import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/system/udp_broadcast_bpf.dart';

import 'udp_broadcast_packet_fixture.dart';

const _source = 0xc0a80107;
const _directed = 0xc0a801ff;

List<SockFilterInstruction> _filter([List<int> sources = const [_source]]) =>
    buildUdpBroadcastBpf(
      physicalSrcIpv4s: sources,
      directedBroadcastIpv4s: const [_directed],
      excludedIfindexes: const {1, 8},
    );

void main() {
  test('admits outbound IPv4 UDP limited/directed broadcast and multicast', () {
    final program = _filter();
    for (final destination in [0xffffffff, _directed, 0xe000023c, 0xeffffffa]) {
      expect(_run(program, udpPacket(destination: destination)), 0xffff);
    }
  });

  test('drops packets outside the capture policy', () {
    final program = _filter();
    final packet = udpPacket();
    expect(_run(program, packet, type: 1), 0);
    expect(_run(program, packet, protocol: 0x86dd), 0);
    expect(_run(program, packet, index: 1), 0);
    expect(_run(program, packet, index: 8), 0);
    expect(_run(program, packet.sublist(0, 12)), 0);
    expect(_run(program, udpPacket()..[9] = 6), 0);
    expect(_run(program, udpPacket()..[6] = 0x20), 0);
    expect(_run(program, udpPacket()..[7] = 1), 0);
    expect(_run(program, udpPacket()..[0] = 0x65), 0);
    expect(_run(program, udpPacket(source: _source + 1)), 0);
    expect(_run(program, udpPacket(destination: _source + 1)), 0);
  });

  test('allows source tables that exceed conditional jump range', () {
    final program = _filter([_source, ...List.generate(300, (i) => i + 1)]);
    for (final source in [_source, 1, 300]) {
      expect(_run(program, udpPacket(source: source)), 0xffff);
    }
    expect(_run(program, udpPacket(source: 301)), 0);
  });

  test('falls back safely at the kernel instruction limit', () {
    final packet = udpPacket();
    final empty = _filter([]);
    expect(empty.length, 1);
    expect(_run(empty, packet), 0);

    final large = _filter(List.generate(2300, (i) => i + 1));
    expect(large.length, lessThanOrEqualTo(4096));
    expect(_run(large, packet), 0xffff);
    expect(_run(large, packet, index: 8), 0);
    expect(_run(large, packet, type: 0), 0);
    expect(_run(large, udpPacket()..[9] = 6), 0);

    final tooManyExclusions = buildUdpBroadcastBpf(
      physicalSrcIpv4s: [_source],
      directedBroadcastIpv4s: [_directed],
      excludedIfindexes: Set.from(List.generate(3000, (i) => i)),
    );
    expect(_run(tooManyExclusions, packet), 0);
  });
}

int _run(
  List<SockFilterInstruction> program,
  Uint8List packet, {
  int type = 4,
  int index = 2,
  int protocol = 0x0800,
}) {
  final bytes = ByteData.sublistView(packet);
  var a = 0;
  for (var pc = 0; pc < program.length; pc++) {
    final op = program[pc];
    final k = op.k;
    switch (op.code) {
      case 0x20:
        a = switch (k) {
          -4096 => protocol,
          -4092 => type,
          -4088 => index,
          _ when k + 4 <= packet.length => bytes.getUint32(k),
          _ => -1,
        };
        if (a < 0) return 0;
      case 0x28:
        if (k + 2 > packet.length) return 0;
        a = bytes.getUint16(k);
      case 0x30:
        if (k >= packet.length) return 0;
        a = packet[k];
      case 0x15:
        pc += a == k ? op.jt : op.jf;
      case 0x45:
        pc += a & k != 0 ? op.jt : op.jf;
      case 0x05:
        pc += k;
      case 0x54:
        a &= k;
      case 0x06:
        return k;
      default:
        throw StateError('Unknown filter instruction ${op.code}');
    }
  }
  throw StateError('Filter did not return');
}

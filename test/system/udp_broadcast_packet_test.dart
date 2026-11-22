import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/system/udp_broadcast_packet.dart';

import 'udp_broadcast_packet_fixture.dart';

const _source = 0xc0a80107;
const _directed = 0xc0a801ff;
const _virtual = 0x0a909001;
const _target = VirtualRelayTarget('a', 'et_a', 3, _virtual, 24, 0x0a9090ff);
final _physical = PhysicalInterface.fromIpAndPrefix(_source, 24, 2, 'eth0')!;

UdpBroadcastNormalization _normalize(
  Uint8List packet, {
  VirtualRelayTarget target = _target,
  List<PhysicalInterface>? physical,
  int? mtu,
}) => normalizeUdpBroadcastPacket(
  packet,
  physicalInterfaces: physical ?? [_physical],
  target: target,
  allVirtualIpv4s: {_virtual, 0x0a909002},
  maxPacketLen: mtu,
);

void main() {
  final destinations = {
    limitedBroadcast: limitedBroadcast,
    _directed: _target.virtualBroadcast,
    0xeffffffa: 0xeffffffa,
    0xe000023c: 0xe000023c,
  };
  for (final entry in destinations.entries) {
    test(
      'rewrites source, ports and checksums for destination ${entry.key}',
      () {
        final original = udpPacket(destination: entry.key);
        final result = _normalize(original) as NormalizedUdpBroadcast;
        final packet = result.packet;
        expect(result.destinationIpv4, entry.value);
        final ip = ByteData.sublistView(packet);
        expect(ip.getUint32(12), _virtual);
        expect(ip.getUint32(16), entry.value);
        expect(ip.getUint16(20), 12345);
        expect(ip.getUint16(22), 37020);
        expect(packet.sublist(28), [1, 2, 3]);
        _expectChecksums(packet);
        expect(ByteData.sublistView(original).getUint16(26), 0xabcd);
      },
    );
  }

  test('accepts a source IP observed on another physical interface', () {
    final other = PhysicalInterface.fromIpAndPrefix(
      0xc0a80209,
      24,
      9,
      'wlan0',
    )!;
    final result = normalizeUdpBroadcastPacket(
      udpPacket(source: _source, destination: other.directedBroadcast),
      physicalInterfaces: [_physical, other],
      target: _target,
      allVirtualIpv4s: {_virtual},
    ) as NormalizedUdpBroadcast;
    expect(result.destinationIpv4, _target.virtualBroadcast);
  });

  test('rejects local network control multicast destinations', () {
    for (final destination in [0xe0000000, 0xe00000ff]) {
      expect(
        _normalize(udpPacket(destination: destination)),
        UdpBroadcastRejection.unsupportedDestination,
      );
    }
  });

  test(
    'uses limited broadcast when a virtual prefix has no directed broadcast',
    () {
      final target = VirtualRelayTarget(
        'a',
        'et_a',
        3,
        _virtual,
        32,
        limitedBroadcast,
      );
      final result = _normalize(
        udpPacket(destination: _directed),
        target: target,
      ) as NormalizedUdpBroadcast;
      expect(result.destinationIpv4, limitedBroadcast);
    },
  );

  test(
    'uses physical and virtual prefix lengths to map directed broadcasts',
    () {
      final physical = PhysicalInterface.fromIpAndPrefix(
        0xac10050a,
        20,
        2,
        'eth0',
      )!;
      expect(physical.directedBroadcast, 0xac100fff);
      const target = VirtualRelayTarget(
        'a',
        'et_a',
        3,
        0x0a000001,
        20,
        0x0a000fff,
      );
      final result = _normalize(
        udpPacket(
          source: physical.ipv4,
          destination: physical.directedBroadcast,
        ),
        physical: [physical],
        target: target,
      ) as NormalizedUdpBroadcast;
      expect(result.destinationIpv4, target.virtualBroadcast);
      expect(prefixLengthFromNetmask(0xfffff000), 20);
      expect(prefixLengthFromNetmask(0xff00ff00), isNull);
      expect(prefixLengthFromNetmask(0xffffffff), 32);
      expect(prefixLengthFromNetmask(0), 0);
    },
  );

  test('keeps IP options and drops bytes after the IPv4 total length', () {
    final original = udpPacket(options: [1, 1, 0, 0]);
    final result = _normalize(
      Uint8List.fromList([...original, 0xff]),
    ) as NormalizedUdpBroadcast;
    expect(result.packet.length, original.length);
    expect(result.packet.sublist(20, 24), [1, 1, 0, 0]);
    expect(result.packet[8], 64);
    _expectChecksums(result.packet);
  });

  test('encodes a zero UDP checksum as all ones', () {
    // This payload completes the one's-complement sum for the rewritten
    // source, limited broadcast destination and the fixture's UDP header.
    final sum = 0x0a90 + 0x9001 + 17 + 10 + 12345 + 37020 + 10;
    final payload = 0xffff - ((sum & 0xffff) + (sum >> 16));
    final result = _normalize(
      udpPacket(payload: [payload >> 8, payload & 0xff]),
    ) as NormalizedUdpBroadcast;
    expect(ByteData.sublistView(result.packet).getUint16(26), 0xffff);
    _expectChecksums(result.packet);
  });

  test('rejects malformed IPv4, non-UDP, fragments and length mismatches', () {
    expect(_normalize(Uint8List(10)), UdpBroadcastRejection.malformedIpv4);
    expect(
      _normalize(udpPacket()..[0] = 0x65),
      UdpBroadcastRejection.notUdpIpv4,
    );
    expect(_normalize(udpPacket()..[9] = 6), UdpBroadcastRejection.notUdpIpv4);
    expect(
      _normalize(udpPacket()..[0] = 0x44),
      UdpBroadcastRejection.badIpv4Length,
    );
    for (final fragment in [1, 0x2000]) {
      final packet = udpPacket();
      ByteData.sublistView(packet).setUint16(6, fragment);
      expect(_normalize(packet), UdpBroadcastRejection.fragmented);
    }
    expect(
      _normalize(udpPacket()..[3] = 255),
      UdpBroadcastRejection.badIpv4Length,
    );
    expect(
      _normalize(udpPacket()..[25] = 7),
      UdpBroadcastRejection.badUdpLength,
    );
    expect(
      _normalize(udpPacket()..[25] = 8),
      UdpBroadcastRejection.badUdpLength,
    );
    expect(_normalize(udpPacket(), mtu: 30), UdpBroadcastRejection.exceedsMtu);
  });

  test('rejects nonphysical, virtual and ignored source addresses', () {
    for (final address in [0, limitedBroadcast, 0x7f000001, 0xe0000001]) {
      expect(
        _normalize(udpPacket(source: address)),
        UdpBroadcastRejection.ignoredSource,
      );
      expect(PhysicalInterface.fromIpAndPrefix(address, 24, 2, 'eth0'), isNull);
    }
    for (final address in [_virtual, _virtual + 1]) {
      expect(
        _normalize(udpPacket(source: address)),
        UdpBroadcastRejection.virtualSourceDuplicate,
      );
    }
    expect(
      _normalize(udpPacket(source: _source + 1)),
      UdpBroadcastRejection.nonPhysicalSource,
    );
    expect(PhysicalInterface.fromIpAndPrefix(_source, 31, 2, 'eth0'), isNull);
    expect(
      PhysicalInterface.fromIpAndPrefix(
        0xa9fe0d0a,
        16,
        2,
        'eth0',
      )?.directedBroadcast,
      0xa9feffff,
    );
  });

  test('rejects unicast and normalized loopback destinations', () {
    expect(
      _normalize(udpPacket(destination: _source)),
      UdpBroadcastRejection.unsupportedDestination,
    );
    const loopback = VirtualRelayTarget(
      'a',
      'et_a',
      3,
      0x7f000001,
      24,
      0x7f0000ff,
    );
    expect(
      _normalize(udpPacket(destination: _directed), target: loopback),
      UdpBroadcastRejection.loopbackDestination,
    );
  });
}

void _expectChecksums(Uint8List packet) {
  final ihl = (packet[0] & 15) * 4;
  final udpLength = packet.length - ihl;
  final pseudoHeader = [
    ...packet.sublist(12, 20),
    0,
    17,
    udpLength >> 8,
    udpLength & 0xff,
  ];
  expect(_foldedSum(packet.sublist(0, ihl)), 0xffff);
  expect(_foldedSum([...pseudoHeader, ...packet.sublist(ihl)]), 0xffff);
}

int _foldedSum(List<int> bytes) {
  var sum = 0;
  for (final (offset, byte) in bytes.indexed) {
    sum += offset.isEven ? byte << 8 : byte;
    sum = (sum & 0xffff) + (sum >> 16);
  }
  return sum;
}

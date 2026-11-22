import 'dart:typed_data';

import '../models/network_flags.dart';

bool udpBroadcastRelayRequested(NetworkFlags flags) =>
    flags.enableUdpBroadcastRelay && !flags.noTun;

const limitedBroadcast = 0xffffffff;

bool isIpv4Multicast(int address) => address & 0xf0000000 == 0xe0000000;
bool _isLoopback(int address) => address >> 24 == 127;
bool _ignoredSource(int address) =>
    address == 0 ||
    address == limitedBroadcast ||
    _isLoopback(address) ||
    isIpv4Multicast(address);

int ipv4Broadcast(int address, int prefix) =>
    address | (limitedBroadcast >> prefix);

int? prefixLengthFromNetmask(int mask) {
  final host = mask ^ limitedBroadcast;
  return host & (host + 1) == 0 ? 32 - host.bitLength : null;
}

final class PhysicalInterface {
  const PhysicalInterface._(
    this.ipv4,
    this.prefixLength,
    this.directedBroadcast,
    this.ifindex,
    this.name,
  );

  static PhysicalInterface? fromIpAndPrefix(
    int address,
    int prefix,
    int ifindex,
    String name,
  ) {
    if (_ignoredSource(address) || prefix < 0 || prefix > 30) return null;
    return PhysicalInterface._(
      address,
      prefix,
      ipv4Broadcast(address, prefix),
      ifindex,
      name,
    );
  }

  final int ipv4;
  final int prefixLength;
  final int directedBroadcast;
  final int ifindex;
  final String name;
}

final class VirtualRelayTarget {
  const VirtualRelayTarget(
    this.networkId,
    this.tunName,
    this.tunIfindex,
    this.virtualIpv4,
    this.prefixLength,
    this.virtualBroadcast,
  );

  final String networkId;
  final String tunName;
  final int tunIfindex;
  final int virtualIpv4;
  final int prefixLength;
  final int virtualBroadcast;
}

sealed class UdpBroadcastNormalization {
  const UdpBroadcastNormalization();
}

enum UdpBroadcastRejection implements UdpBroadcastNormalization {
  malformedIpv4,
  notUdpIpv4,
  fragmented,
  badIpv4Length,
  ignoredSource,
  virtualSourceDuplicate,
  nonPhysicalSource,
  unsupportedDestination,
  loopbackDestination,
  badUdpLength,
  exceedsMtu,
}

final class NormalizedUdpBroadcast extends UdpBroadcastNormalization {
  const NormalizedUdpBroadcast(this.packet, this.destinationIpv4);

  final Uint8List packet;
  final int destinationIpv4;
}

UdpBroadcastNormalization normalizeUdpBroadcastPacket(
  Uint8List packet, {
  required List<PhysicalInterface> physicalInterfaces,
  required VirtualRelayTarget target,
  required Set<int> allVirtualIpv4s,
  int? maxPacketLen,
}) {
  if (packet.length < 20) return UdpBroadcastRejection.malformedIpv4;
  final ihl = (packet[0] & 15) * 4;
  if (packet[0] >> 4 != 4 || packet[9] != 17) {
    return UdpBroadcastRejection.notUdpIpv4;
  }
  final input = ByteData.sublistView(packet);
  if (input.getUint16(6) & 0x3fff != 0) {
    return UdpBroadcastRejection.fragmented;
  }
  final length = input.getUint16(2);
  if (ihl < 20 || length < ihl + 8 || length > packet.length) {
    return UdpBroadcastRejection.badIpv4Length;
  }
  final src = input.getUint32(12);
  if (_ignoredSource(src)) return UdpBroadcastRejection.ignoredSource;
  if (src == target.virtualIpv4 || allVirtualIpv4s.contains(src)) {
    return UdpBroadcastRejection.virtualSourceDuplicate;
  }
  if (!physicalInterfaces.any((interface) => interface.ipv4 == src)) {
    return UdpBroadcastRejection.nonPhysicalSource;
  }

  final originalDst = input.getUint32(16);
  final int dst;
  if (originalDst == limitedBroadcast || isIpv4Multicast(originalDst)) {
    dst = originalDst;
  } else if (physicalInterfaces.any(
    (interface) => interface.directedBroadcast == originalDst,
  )) {
    dst = target.virtualBroadcast;
  } else {
    return UdpBroadcastRejection.unsupportedDestination;
  }
  if (_isLoopback(dst)) return UdpBroadcastRejection.loopbackDestination;

  final udpLength = input.getUint16(ihl + 4);
  if (udpLength < 8 || ihl + udpLength != length) {
    return UdpBroadcastRejection.badUdpLength;
  }
  if (maxPacketLen != null && length > maxPacketLen) {
    return UdpBroadcastRejection.exceedsMtu;
  }

  final normalized = packet.sublist(0, length);
  final output = ByteData.sublistView(normalized)
    ..setUint16(2, length)
    ..setUint32(12, target.virtualIpv4)
    ..setUint32(16, dst)
    ..setUint16(10, 0)
    ..setUint16(ihl + 6, 0);
  output.setUint16(10, _checksum(output, 0, ihl));
  final pseudoHeader =
      output.getUint16(12) +
      output.getUint16(14) +
      output.getUint16(16) +
      output.getUint16(18) +
      17 +
      udpLength;
  final udpChecksum = _checksum(output, ihl, length, pseudoHeader);
  output.setUint16(ihl + 6, udpChecksum == 0 ? 0xffff : udpChecksum);
  return NormalizedUdpBroadcast(normalized, dst);
}

int _checksum(ByteData bytes, int offset, int end, [int sum = 0]) {
  for (; offset + 1 < end; offset += 2) {
    sum += bytes.getUint16(offset);
  }
  if (offset < end) sum += bytes.getUint8(offset) << 8;
  while (sum > 0xffff) {
    sum = (sum & 0xffff) + (sum >> 16);
  }
  return sum ^ 0xffff;
}

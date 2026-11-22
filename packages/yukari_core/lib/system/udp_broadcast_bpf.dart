import 'udp_broadcast_packet.dart';

final class SockFilterInstruction {
  const SockFilterInstruction(this.code, this.jt, this.jf, this.k);

  final int code;
  final int jt;
  final int jf;
  final int k;
}

const _drop = SockFilterInstruction(0x06, 0, 0, 0);
const _accept = SockFilterInstruction(0x06, 0, 0, 0xffff);

List<SockFilterInstruction> buildUdpBroadcastBpf({
  required List<int> physicalSrcIpv4s,
  required List<int> directedBroadcastIpv4s,
  required Set<int> excludedIfindexes,
}) {
  if (physicalSrcIpv4s.isEmpty) return const [_drop];
  final base = [
    // SKF_AD_PKTTYPE (PACKET_OUTGOING), SKF_AD_PROTOCOL (ETH_P_IP).
    const SockFilterInstruction(0x20, 0, 0, -4092),
    const SockFilterInstruction(0x15, 1, 0, 4),
    _drop,
    const SockFilterInstruction(0x20, 0, 0, -4096),
    const SockFilterInstruction(0x15, 1, 0, 0x0800),
    _drop,
    const SockFilterInstruction(0x20, 0, 0, -4088),
    for (final index in excludedIfindexes) ...[
      SockFilterInstruction(0x15, 0, 1, index),
      _drop,
    ],
    const SockFilterInstruction(0x30, 0, 0, 0),
    const SockFilterInstruction(0x54, 0, 0, 0xf0),
    const SockFilterInstruction(0x15, 1, 0, 0x40),
    _drop,
    const SockFilterInstruction(0x30, 0, 0, 9),
    const SockFilterInstruction(0x15, 1, 0, 17),
    _drop,
    const SockFilterInstruction(0x28, 0, 0, 6),
    const SockFilterInstruction(0x45, 0, 1, 0x3fff),
    _drop,
  ];
  const maxInstructions = 4096;
  if (base.length + 1 > maxInstructions) return const [_drop];

  final sources = physicalSrcIpv4s.toSet().toList();
  final destinations = directedBroadcastIpv4s.toSet();
  if (base.length + 2 * (sources.length + destinations.length) + 15 >
      maxInstructions) {
    // A large address list is checked in userspace. Device exclusions and
    // protocol/direction checks remain in the kernel.
    return [...base, _accept];
  }
  return [
    ...base,
    const SockFilterInstruction(0x20, 0, 0, 12),
    for (var i = 0; i < sources.length; i++) ...[
      SockFilterInstruction(0x15, 0, 1, sources[i]),
      // JA has a 32-bit displacement, unlike the conditional branches.
      SockFilterInstruction(0x05, 0, 0, 2 * (sources.length - i - 1) + 1),
    ],
    _drop,
    const SockFilterInstruction(0x20, 0, 0, 16),
    const SockFilterInstruction(0x15, 0, 1, 0xffffffff),
    _accept,
    for (final destination in destinations) ...[
      SockFilterInstruction(0x15, 0, 1, destination),
      _accept,
    ],
    const SockFilterInstruction(0x20, 0, 0, 16),
    const SockFilterInstruction(0x54, 0, 0, 0xffffff00),
    const SockFilterInstruction(0x15, 0, 1, localNetworkControlMulticast),
    _drop,
    const SockFilterInstruction(0x20, 0, 0, 16),
    const SockFilterInstruction(0x54, 0, 0, 0xf0000000),
    const SockFilterInstruction(0x15, 0, 1, 0xe0000000),
    _accept,
    _drop,
  ];
}

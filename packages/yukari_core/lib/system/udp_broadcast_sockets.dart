import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'udp_broadcast_bpf.dart';
import 'udp_broadcast_linux_ffi.dart';
import 'udp_broadcast_packet.dart';

int _open(int domain, int type, int protocol, String label) => checkedFd(
  LinuxRelayLibc.socket(domain, type | nonblockCloexec, protocol),
  label,
);

int openBroadcastCapture() {
  final fd = _open(afPacket, sockDgram, 0, 'AF_PACKET capture');
  try {
    // Outgoing frames are delivered to ETH_P_ALL listeners. Attach a
    // drop-all filter before subscribing, then replace it on the first scan.
    attachBroadcastFilter(fd, const [SockFilterInstruction(0x06, 0, 0, 0)]);
    setIntOption(fd, solSocket, soReceiveBuffer, 256 * 1024);
    using((arena) {
      final address = arena<SockAddrLl>()
        ..ref.family = afPacket
        ..ref.protocol = networkUint16(ethAll);
      checkedFd(
        LinuxRelayLibc.bind(fd, address.cast(), sizeOf<SockAddrLl>()),
        'bind AF_PACKET capture',
      );
    });
    return fd;
  } catch (_) {
    LinuxRelayLibc.close(fd);
    rethrow;
  }
}

int openRelayNetlink() {
  final fd = _open(afNetlink, sockRaw, 0, 'NETLINK_ROUTE');
  try {
    using((arena) {
      final address = arena<SockAddrNl>()
        ..ref.family = afNetlink
        ..ref.groups = 1 | 0x10; // RTMGRP_LINK | RTMGRP_IPV4_IFADDR
      checkedFd(
        LinuxRelayLibc.bind(fd, address.cast(), sizeOf<SockAddrNl>()),
        'bind NETLINK_ROUTE',
      );
    });
    return fd;
  } catch (_) {
    LinuxRelayLibc.close(fd);
    rethrow;
  }
}

void attachBroadcastFilter(int fd, List<SockFilterInstruction> program) {
  using((arena) {
    final instructions = arena<SockFilter>(program.length);
    for (var i = 0; i < program.length; i++) {
      final op = program[i];
      (instructions + i).ref
        ..code = op.code
        ..jt = op.jt
        ..jf = op.jf
        ..k = op.k.toUnsigned(32);
    }
    final filter = arena<SockFprog>()
      ..ref.len = program.length
      ..ref.instructions = instructions;
    checkedFd(
      LinuxRelayLibc.setOption(
        fd,
        solSocket,
        soAttachFilter,
        filter.cast(),
        sizeOf<SockFprog>(),
      ),
      'SO_ATTACH_FILTER',
    );
  });
}

final class BroadcastTransmitter {
  BroadcastTransmitter(this.log);

  final void Function(String) log;
  final _packetFd = _open(afPacket, sockDgram, 0, 'AF_PACKET transmit');
  final _fallback = <(int, String), int>{};
  final _arena = Arena();
  late final _payload = _arena<Uint8>(0xffff);
  late final _linkAddress = _arena<SockAddrLl>()
    ..ref.family = afPacket
    ..ref.protocol = networkUint16(ethIp);
  late final _ipAddress = _arena<SockAddrIn>()..ref.family = afInet;

  int send(VirtualRelayTarget target, NormalizedUdpBroadcast datagram) {
    final packet = datagram.packet;
    _payload.asTypedList(packet.length).setAll(0, packet);
    final key = (target.tunIfindex, target.tunName);
    var raw = _fallback[key];
    if (raw == null) {
      _linkAddress.ref.ifindex = target.tunIfindex;
      final count = LinuxRelayLibc.sendTo(
        _packetFd,
        _payload,
        packet.length,
        0,
        _linkAddress.cast(),
        sizeOf<SockAddrLl>(),
      );
      if (count >= 0) return 0;
      final error = LinuxRelayLibc.errno;
      if (error != einval && error != eopnotsupp) return error;
      raw = _openFallback(target.tunName);
      if (raw < 0) return -raw;
      _fallback[key] = raw;
      log('Using raw IPv4 UDP broadcast relay transmit on ${target.tunName}');
    }
    _ipAddress.ref.address = networkUint32(datagram.destinationIpv4);
    final count = LinuxRelayLibc.sendTo(
      raw,
      _payload,
      packet.length,
      0,
      _ipAddress.cast(),
      sizeOf<SockAddrIn>(),
    );
    return count >= 0 ? 0 : LinuxRelayLibc.errno;
  }

  int _openFallback(String name) {
    final fd = LinuxRelayLibc.socket(
      afInet,
      sockRaw | nonblockCloexec,
      ipProtoRaw,
    );
    if (fd < 0) {
      final error = LinuxRelayLibc.errno;
      return -(error == 0 ? einval : error);
    }
    return using((arena) {
      final device = name.toNativeUtf8(allocator: arena);
      var error = setIntOption(fd, ipProtoIp, ipHdrIncl, 1);
      if (error == 0) error = setIntOption(fd, solSocket, soBroadcast, 1);
      if (error == 0) error = setIntOption(fd, ipProtoIp, ipMulticastLoop, 0);
      if (error == 0 &&
          LinuxRelayLibc.setOption(
                fd,
                solSocket,
                soBindToDevice,
                device.cast(),
                device.length + 1,
              ) ==
              0) {
        return fd;
      }
      if (error == 0) error = LinuxRelayLibc.errno;
      LinuxRelayLibc.close(fd);
      return -(error == 0 ? einval : error);
    });
  }

  void retain(Iterable<VirtualRelayTarget> targets) {
    final active = {
      for (final target in targets) (target.tunIfindex, target.tunName),
    };
    for (final key in _fallback.keys.toList()) {
      if (!active.contains(key)) LinuxRelayLibc.close(_fallback.remove(key)!);
    }
  }

  void dispose() {
    retain(const []);
    LinuxRelayLibc.close(_packetFd);
    _arena.releaseAll();
  }
}

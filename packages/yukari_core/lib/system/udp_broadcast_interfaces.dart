import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'udp_broadcast_linux_ffi.dart';
import 'udp_broadcast_packet.dart';

typedef RelayRegistration = ({VirtualRelayTarget target, bool followsDhcp});
typedef RelayDevice = ({VirtualRelayTarget target, int? mtu});

const _up = 1, _broadcast = 2, _loopback = 8, _pointToPoint = 16, _running = 64;
const _physicalFlags = _up | _running | _broadcast;

final class LinuxIpv4Interface {
  const LinuxIpv4Interface(
    this.name,
    this.index,
    this.ipv4,
    this.prefix,
    this.flags,
    this.tun,
    this.mtu,
  );

  final String name;
  final int index;
  final int ipv4;
  final int prefix;
  final int flags;
  final bool tun;
  final int? mtu;

  bool get isLoopback => flags & _loopback != 0;

  bool get isTunnel => tun || flags & _pointToPoint != 0;

  PhysicalInterface? get physical =>
      !tun &&
          flags & _physicalFlags == _physicalFlags &&
          flags & (_loopback | _pointToPoint) == 0
      ? PhysicalInterface.fromIpAndPrefix(ipv4, prefix, index, name)
      : null;
}

List<LinuxIpv4Interface> enumerateLinuxIpv4Interfaces() => using((arena) {
  final head = arena<Pointer<IfAddrs>>();
  checkedFd(LinuxRelayLibc.getIfAddrs(head), 'getifaddrs');
  try {
    final result = <LinuxIpv4Interface>[];
    for (var ptr = head.value; ptr != nullptr; ptr = ptr.ref.next) {
      final info = ptr.ref;
      if (info.addr == nullptr ||
          info.netmask == nullptr ||
          info.addr.ref.family != afInet ||
          info.netmask.ref.family != afInet ||
          info.name == nullptr) {
        continue;
      }
      final prefix = prefixLengthFromNetmask(
        networkUint32(info.netmask.ref.address),
      );
      final index = LinuxRelayLibc.ifNameToIndex(info.name);
      if (prefix == null || index == 0) continue;
      final name = info.name.toDartString();
      final tunFlags = _readInterfaceValue(name, 'tun_flags');
      result.add(
        LinuxIpv4Interface(
          name,
          index,
          networkUint32(info.addr.ref.address),
          prefix,
          info.flags,
          tunFlags != null
              ? tunFlags & 1 != 0
              : info.flags & _pointToPoint != 0,
          _readInterfaceValue(name, 'mtu'),
        ),
      );
    }
    return result;
  } finally {
    LinuxRelayLibc.freeIfAddrs(head.value);
  }
});

int? _readInterfaceValue(String name, String property) {
  try {
    return int.tryParse(
      File('/sys/class/net/$name/$property').readAsStringSync().trim(),
    );
  } on FileSystemException {
    return null;
  }
}

/// Resolves an up L3 TUN by name or by the instance's assigned address.
/// Only unique matches are usable. An established TUN can change its address
/// on the same link while EasyTier is renewing a DHCP lease.
LinuxIpv4Interface? findRelayTun(
  List<LinuxIpv4Interface> interfaces, {
  required String name,
  required int? address,
  VirtualRelayTarget? previous,
  bool followsDhcp = false,
}) {
  final tuns = interfaces.where(
    (device) =>
        device.isTunnel &&
        device.flags & _up != 0 &&
        device.ipv4 != 0 &&
        !device.isLoopback &&
        !isIpv4Multicast(device.ipv4) &&
        device.ipv4 != limitedBroadcast,
  );
  final named = tuns.where((device) => device.name == name);
  final exact = named.where(
    (device) => address == null || device.ipv4 == address,
  );
  if (exact.length == 1) return exact.single;
  if (previous != null && followsDhcp) {
    final sameLink = tuns.where(
      (device) =>
          device.index == previous.tunIfindex &&
          device.name == previous.tunName,
    );
    if (sameLink.length == 1) return sameLink.single;
  }
  if (address != null) {
    final owned = tuns.where((device) => device.ipv4 == address);
    if (owned.length == 1) return owned.single;
  }
  return null;
}

VirtualRelayTarget relayTarget(String id, LinuxIpv4Interface device) =>
    VirtualRelayTarget(
      id,
      device.name,
      device.index,
      device.ipv4,
      device.prefix,
      device.prefix >= 31
          ? limitedBroadcast
          : ipv4Broadcast(device.ipv4, device.prefix),
    );

Map<String, RelayDevice> resolveRelayTargets(
  List<LinuxIpv4Interface> interfaces,
  List<RelayRegistration> registrations,
  Map<String, RelayDevice> previous,
) {
  final targets = <String, RelayDevice>{};
  for (final registration in registrations) {
    final target = registration.target;
    final device = findRelayTun(
      interfaces,
      name: target.tunName,
      address: target.virtualIpv4,
      previous: previous[target.networkId]?.target,
      followsDhcp: registration.followsDhcp,
    );
    if (device != null) {
      targets[target.networkId] = (
        target: relayTarget(target.networkId, device),
        mtu: device.mtu,
      );
    }
  }
  return targets;
}

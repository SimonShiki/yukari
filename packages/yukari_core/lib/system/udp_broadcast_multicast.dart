import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'udp_broadcast_linux_ffi.dart';
import 'udp_broadcast_packet.dart';

Map<String, Set<int>> parseProcNetIgmp(String content, {Endian? byteOrder}) {
  final interfaces = <String, Set<int>>{};
  final deviceRow = RegExp(r'^\s*\d+\s+(\S+)\s*:\s+\d+');
  final groupRow = RegExp(r'^\s+([0-9a-fA-F]{8})\s+');
  Set<int>? groups;
  for (final line in content.split('\n')) {
    if (deviceRow.firstMatch(line)?.group(1) case final name?) {
      groups = interfaces.putIfAbsent(name, () => {});
    } else if (groupRow.firstMatch(line)?.group(1) case final word?) {
      final raw = int.parse(word, radix: 16);
      final address = (byteOrder ?? Endian.host) == Endian.little
          ? ((raw & 0xff) << 24) |
                ((raw & 0xff00) << 8) |
                ((raw >> 8) & 0xff00) |
                (raw >> 24)
          : raw;
      if (isIpv4Multicast(address) && address >= 0xe0000100) {
        groups?.add(address);
      }
    }
  }
  return interfaces;
}

Set<int> multicastGroupsForInterfaces(
  Map<String, Set<int>> groups,
  Iterable<String> physicalNames,
  Set<int> current,
) {
  final desired = {for (final name in physicalNames) ...?groups[name]};
  // Keep surviving groups first when the combined list exceeds the cap.
  return {...current.intersection(desired), ...desired}.take(20).toSet();
}

final class MulticastGroupMirror {
  MulticastGroupMirror({
    String Function()? readIgmp,
    int Function(int)? closeSocket,
  }) : _readIgmp = readIgmp ?? _readProcNetIgmp,
       _closeSocket = closeSocket ?? LinuxRelayLibc.close;

  final String Function() _readIgmp;
  final int Function(int) _closeSocket;
  final _sockets = <int, ({int fd, Set<int> groups})>{};

  void sync(Set<int> indexes, Set<String> physicalNames) {
    for (final index in _sockets.keys.toList()) {
      if (!indexes.contains(index)) removeTun(index);
    }
    if (indexes.isEmpty) return;
    if (physicalNames.isEmpty) {
      dispose();
      return;
    }
    final String content;
    try {
      content = _readIgmp();
    } on FileSystemException {
      return;
    }
    final groups = parseProcNetIgmp(content);
    for (final index in indexes) {
      final current = _sockets[index]?.groups ?? <int>{};
      final desired = multicastGroupsForInterfaces(
        groups,
        physicalNames,
        current,
      );
      if (desired.isEmpty) {
        removeTun(index);
        continue;
      }
      // Linux limits memberships per socket. Give each TUN its own limit.
      final fd =
          _sockets[index]?.fd ??
          LinuxRelayLibc.socket(afInet, sockDgram | nonblockCloexec, 0);
      if (fd < 0) continue;
      _sockets[index] = (fd: fd, groups: current);
      using((arena) {
        final request = arena<IpMreqn>()..ref.ifindex = index;
        for (final group in current.difference(desired)) {
          _membership(fd, ipDropMembership, request, group);
          current.remove(group);
        }
        for (final group in desired.difference(current)) {
          if (_membership(fd, ipAddMembership, request, group)) {
            current.add(group);
          }
        }
      });
    }
  }

  void removeTun(int index) {
    final socket = _sockets.remove(index);
    if (socket != null) _closeSocket(socket.fd);
  }

  void dispose() {
    for (final index in _sockets.keys.toList()) {
      removeTun(index);
    }
  }
}

String _readProcNetIgmp() => File('/proc/net/igmp').readAsStringSync();

bool _membership(int fd, int option, Pointer<IpMreqn> request, int group) {
  request.ref.group = networkUint32(group);
  return LinuxRelayLibc.setOption(
        fd,
        ipProtoIp,
        option,
        request.cast(),
        sizeOf<IpMreqn>(),
      ) ==
      0;
}

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class LinuxRelayLibc {
  static final _libc = DynamicLibrary.process();

  static final socket = _libc
      .lookupFunction<Int Function(Int, Int, Int), int Function(int, int, int)>(
        'socket',
        isLeaf: true,
      );
  static final bind = _libc
      .lookupFunction<
        Int Function(Int, Pointer<Void>, Uint32),
        int Function(int, Pointer<Void>, int)
      >('bind', isLeaf: true);
  static final setOption = _libc
      .lookupFunction<
        Int Function(Int, Int, Int, Pointer<Void>, Uint32),
        int Function(int, int, int, Pointer<Void>, int)
      >('setsockopt', isLeaf: true);
  static final recvFrom = _libc
      .lookupFunction<
        IntPtr Function(
          Int,
          Pointer<Uint8>,
          Size,
          Int,
          Pointer<Void>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          Pointer<Uint8>,
          int,
          int,
          Pointer<Void>,
          Pointer<Uint32>,
        )
      >('recvfrom', isLeaf: true);
  static final sendTo = _libc
      .lookupFunction<
        IntPtr Function(Int, Pointer<Uint8>, Size, Int, Pointer<Void>, Uint32),
        int Function(int, Pointer<Uint8>, int, int, Pointer<Void>, int)
      >('sendto', isLeaf: true);
  static final close = _libc
      .lookupFunction<Int Function(Int), int Function(int)>(
        'close',
        isLeaf: true,
      );
  static final getOption = _libc
      .lookupFunction<
        Int Function(Int, Int, Int, Pointer<Void>, Pointer<Uint32>),
        int Function(int, int, int, Pointer<Void>, Pointer<Uint32>)
      >('getsockopt', isLeaf: true);
  static final poll = _libc
      .lookupFunction<
        Int Function(Pointer<PollFd>, UnsignedLong, Int),
        int Function(Pointer<PollFd>, int, int)
      >('poll');
  static final eventfd = _libc
      .lookupFunction<Int Function(UnsignedInt, Int), int Function(int, int)>(
        'eventfd',
        isLeaf: true,
      );
  static final read = _libc
      .lookupFunction<
        IntPtr Function(Int, Pointer<Void>, Size),
        int Function(int, Pointer<Void>, int)
      >('read', isLeaf: true);
  static final write = _libc
      .lookupFunction<
        IntPtr Function(Int, Pointer<Void>, Size),
        int Function(int, Pointer<Void>, int)
      >('write', isLeaf: true);
  static final getIfAddrs = _libc
      .lookupFunction<
        Int Function(Pointer<Pointer<IfAddrs>>),
        int Function(Pointer<Pointer<IfAddrs>>)
      >('getifaddrs');
  static final freeIfAddrs = _libc
      .lookupFunction<
        Void Function(Pointer<IfAddrs>),
        void Function(Pointer<IfAddrs>)
      >('freeifaddrs');
  static final ifNameToIndex = _libc
      .lookupFunction<
        UnsignedInt Function(Pointer<Utf8>),
        int Function(Pointer<Utf8>)
      >('if_nametoindex', isLeaf: true);
  static final _errno = _libc
      .lookupFunction<Pointer<Int> Function(), Pointer<Int> Function()>(
        '__errno_location',
        isLeaf: true,
      );

  static int get errno => _errno().value;
}

const afInet = 2, afNetlink = 16, afPacket = 17;
const sockDgram = 2, sockRaw = 3, nonblockCloexec = 0x80800;
const ethIp = 0x0800, ethAll = 0x0003;
const solSocket = 1, soError = 4, soReceiveBuffer = 8;
const soBindToDevice = 25, soAttachFilter = 26;
const ipProtoIp = 0, ipProtoRaw = 255;
const pollErr = 0x008, pollHup = 0x010, pollNval = 0x020;
const packetOutgoing = 4;
const eintr = 4, enxio = 6, enodev = 19, einval = 22, eopnotsupp = 95;

int networkUint16(int n) =>
    Endian.host == Endian.little ? ((n & 0xff) << 8) | (n >> 8) : n;

int networkUint32(int n) => Endian.host == Endian.little
    ? (networkUint16(n & 0xffff) << 16) | networkUint16(n >> 16)
    : n;

int checkedFd(int fd, String operation) {
  if (fd < 0) {
    throw StateError('$operation failed (errno ${LinuxRelayLibc.errno})');
  }
  return fd;
}

int getIntOption(int fd, int level, int option) => using((arena) {
  final data = arena<Int>();
  final length = arena<Uint32>()..value = sizeOf<Int>();
  if (LinuxRelayLibc.getOption(fd, level, option, data.cast(), length) != 0) {
    return LinuxRelayLibc.errno;
  }
  return data.value;
});

bool setIntOption(int fd, int level, int option, int value) => using((arena) {
  final data = arena<Int>()..value = value;
  return LinuxRelayLibc.setOption(
        fd,
        level,
        option,
        data.cast(),
        sizeOf<Int>(),
      ) ==
      0;
});

final class IfAddrs extends Struct {
  external Pointer<IfAddrs> next;
  external Pointer<Utf8> name;
  @UnsignedInt()
  external int flags;
  external Pointer<SockAddrIn> addr;
  external Pointer<SockAddrIn> netmask;
  external Pointer<Void> unionAddress;
  external Pointer<Void> data;
}

final class SockAddrIn extends Struct {
  @Uint16()
  external int family;
  @Uint16()
  external int port;
  @Uint32()
  external int address;
  @Array(8)
  external Array<Uint8> padding;
}

final class SockAddrLl extends Struct {
  @Uint16()
  external int family;
  @Uint16()
  external int protocol;
  @Int()
  external int ifindex;
  @Uint16()
  external int hardwareType;
  @Uint8()
  external int packetType;
  @Uint8()
  external int addressLength;
  @Array(8)
  external Array<Uint8> address;
}

final class SockAddrNl extends Struct {
  @Uint16()
  external int family;
  @Uint16()
  external int padding;
  @Uint32()
  external int pid;
  @Uint32()
  external int groups;
}

final class PollFd extends Struct {
  @Int()
  external int fd;
  @Int16()
  external int events;
  @Int16()
  external int revents;
}

final class SockFilter extends Struct {
  @Uint16()
  external int code;
  @Uint8()
  external int jt;
  @Uint8()
  external int jf;
  @Uint32()
  external int k;
}

final class SockFprog extends Struct {
  @Uint16()
  external int len;
  external Pointer<SockFilter> instructions;
}

final class IpMreqn extends Struct {
  @Uint32()
  external int group;
  @Uint32()
  external int localAddress;
  @Int()
  external int ifindex;
}

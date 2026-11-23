import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'udp_broadcast_bpf.dart';
import 'udp_broadcast_interfaces.dart';
import 'udp_broadcast_linux_ffi.dart';
import 'udp_broadcast_multicast.dart';
import 'udp_broadcast_packet.dart';
import 'udp_broadcast_sockets.dart';

final class BroadcastCapture {
  BroadcastCapture._(
    this._capture,
    this._netlink,
    this._event,
    this._tx,
    this.log,
  ) {
    for (final (index, fd) in [_capture, _netlink, _event].indexed) {
      (_polls + index).ref
        ..fd = fd
        ..events = 1; // POLLIN
    }
    log('Started UDP broadcast relay (AF_PACKET)');
  }

  static BroadcastCapture open(int event, void Function(String) log) {
    final capture = openBroadcastCapture();
    var netlink = -1;
    try {
      netlink = openRelayNetlink();
      return BroadcastCapture._(
        capture,
        netlink,
        event,
        BroadcastTransmitter(log),
        log,
      );
    } catch (_) {
      LinuxRelayLibc.close(capture);
      if (netlink >= 0) LinuxRelayLibc.close(netlink);
      rethrow;
    }
  }

  final int _capture, _netlink, _event;
  final BroadcastTransmitter _tx;
  final void Function(String) log;
  final _arena = Arena();
  final _mirror = MulticastGroupMirror();
  final _clock = Stopwatch()..start();
  late final _polls = _arena<PollFd>(3);
  late final _counter = _arena<Uint64>();
  late final _payload = _arena<Uint8>(0xffff);
  late final _sender = _arena<SockAddrLl>();
  late final _senderLength = _arena<Uint32>();

  List<RelayRegistration> _registrations = const [];
  var _targets = <String, RelayDevice>{};
  List<PhysicalInterface> _physical = const [];
  Set<int> _excluded = const {};
  Set<int> _virtualIpv4s = const {};
  int? _rescanAt;
  int _mirrorAt = 0;
  int _statsAt = 60000;
  int _forwarded = 0, _failed = 0;

  void configure(List<RelayRegistration> registrations) {
    _registrations = registrations;
    _scan();
  }

  void _scan() {
    final interfaces = enumerateLinuxIpv4Interfaces();
    _targets = resolveRelayTargets(interfaces, _registrations, _targets);
    _excluded = {
      for (final device in interfaces)
        if (device.isTunnel || device.isLoopback) device.index,
    };
    _virtualIpv4s = {
      for (final device in interfaces)
        if (device.isTunnel) device.ipv4,
    };
    _physical = [
      for (final device in interfaces)
        if (!_virtualIpv4s.contains(device.ipv4)) ?device.physical,
    ];
    attachBroadcastFilter(
      _capture,
      buildUdpBroadcastBpf(
        physicalSrcIpv4s: _targets.isEmpty
            ? const []
            : [for (final item in _physical) item.ipv4],
        directedBroadcastIpv4s: _targets.isEmpty
            ? const []
            : [for (final item in _physical) item.directedBroadcast],
        excludedIfindexes: _excluded,
      ),
    );
    _tx.retain(_targets.values.map((entry) => entry.target));
    _rescanAt = null;
    _syncMulticast();
    log(
      'UDP broadcast relay sees ${_physical.map((item) => item.ifindex).toSet().length} physical interfaces and ${_targets.length} targets',
    );
  }

  void _syncMulticast() {
    _mirror.sync(
      {for (final entry in _targets.values) entry.target.tunIfindex},
      {for (final item in _physical) item.name},
    );
    _mirrorAt = _clock.elapsedMilliseconds + 2000;
  }

  /// Returns true when a command is ready for the Dart message loop.
  bool poll() {
    final now = _clock.elapsedMilliseconds;
    final deadline = _rescanAt ?? _mirrorAt;
    final result = LinuxRelayLibc.poll(
      _polls,
      3,
      (deadline - now).clamp(0, 2000),
    );
    if (result < 0) {
      if (LinuxRelayLibc.errno == eintr) return false;
      checkedFd(result, 'poll UDP broadcast relay');
    }
    if (pollHasDisconnect(
      _polls.ref.revents,
      (_polls + 1).ref.revents,
      (_polls + 2).ref.revents,
    )) {
      throw StateError('UDP broadcast relay lost a socket');
    }
    if (_polls.ref.revents & pollErr != 0) {
      final error = getIntOption(_capture, solSocket, soError);
      if (error != 0) {
        log(
          'UDP broadcast capture reported socket error $error; refreshing interfaces',
        );
      }
      _rescanAt ??= _clock.elapsedMilliseconds + 200;
    }
    if ((_polls + 2).ref.revents & 1 != 0) {
      int count;
      do {
        count = LinuxRelayLibc.read(_event, _counter.cast(), sizeOf<Uint64>());
      } while (count < 0 && LinuxRelayLibc.errno == eintr);
      checkedFd(count, 'read UDP broadcast relay eventfd');
      return true;
    }
    if ((_polls + 1).ref.revents != 0) {
      // Bound each drain to keep stop/reconfigure responsive under load.
      for (var i = 0; i < 64; i++) {
        if (LinuxRelayLibc.read(_netlink, _payload.cast(), 0xffff) < 0) break;
      }
      _rescanAt ??= _clock.elapsedMilliseconds + 200;
    }
    final current = _clock.elapsedMilliseconds;
    if (_rescanAt case final rescan?) {
      if (current >= rescan) _scan();
    } else if (current >= _mirrorAt) {
      _syncMulticast();
    }
    if (_polls.ref.revents & 1 != 0) _drainPackets();
    if (current >= _statsAt) {
      if (_forwarded != 0 || _failed != 0) {
        log(
          'UDP broadcast relay forwarded $_forwarded packets, $_failed sends failed',
        );
      }
      _forwarded = _failed = 0;
      _statsAt = current + 60000;
    }
    return false;
  }

  static final int _ethIpProtocol = networkUint16(ethIp);

  void _drainPackets() {
    for (var i = 0; i < 64; i++) {
      _senderLength.value = sizeOf<SockAddrLl>();
      final length = LinuxRelayLibc.recvFrom(
        _capture,
        _payload,
        0xffff,
        0,
        _sender.cast(),
        _senderLength,
      );
      if (length < 0) return;
      final source = _sender.ref;
      if (source.packetType != packetOutgoing ||
          source.protocol != _ethIpProtocol ||
          _excluded.contains(source.ifindex)) {
        continue;
      }
      final packet = _payload.asTypedList(length);
      final destinations = <(int, int)>{};
      for (final entry in _targets.values) {
        final target = entry.target;
        // A shared TUN can have multiple networks using the same virtual IP.
        if (!destinations.add((target.tunIfindex, target.virtualIpv4))) {
          continue;
        }
        final result = normalizeUdpBroadcastPacket(
          packet,
          physicalInterfaces: _physical,
          target: target,
          allVirtualIpv4s: _virtualIpv4s,
          maxPacketLen: entry.mtu,
        );
        if (result is! NormalizedUdpBroadcast) continue;
        final error = _tx.send(target, result);
        if (error == 0) {
          _forwarded++;
        } else {
          _failed++;
          if (error == enodev || error == enxio) {
            log(
              'UDP broadcast relay lost ${target.tunName}, refreshing interfaces',
            );
            _rescanAt = _clock.elapsedMilliseconds;
            return;
          }
        }
      }
    }
  }

  void dispose() {
    _mirror.dispose();
    _tx.dispose();
    LinuxRelayLibc.close(_capture);
    LinuxRelayLibc.close(_netlink);
    _arena.releaseAll();
  }
}

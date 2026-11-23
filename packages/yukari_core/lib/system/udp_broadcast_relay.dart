import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../backend/privilege.dart';
import '../models/models.dart';
import 'magic_dns.dart' show magicDnsIpAddress;
import 'udp_broadcast_interfaces.dart';
import 'udp_broadcast_packet.dart';
import 'udp_broadcast_worker.dart';

abstract interface class UdpBroadcastRelaySetup {
  bool appliesTo(Network network);
  Future<String?> start(String networkId, Network network);
  Future<void> stop(String networkId);
  Future<void> stopAll();
}

final class UdpBroadcastRelayAuto implements UdpBroadcastRelaySetup {
  UdpBroadcastRelayAuto({
    this.assignedAddress,
    this.attempts = 40,
    this.retryDelay = const Duration(milliseconds: 500),
    void Function(String)? log,
    bool Function()? available,
    List<LinuxIpv4Interface> Function()? interfaces,
    Future<void> Function(List<RelayRegistration>)? configure,
  }) : _log = log ?? stderr.writeln,
       _available = available ?? _linuxCanRelay,
       _interfaces = interfaces ?? enumerateLinuxIpv4Interfaces {
    _configure = configure ?? UdpBroadcastWorker(_log).update;
  }

  final Future<String?> Function(String)? assignedAddress;
  final int attempts;
  final Duration retryDelay;
  final void Function(String) _log;
  final bool Function() _available;
  final List<LinuxIpv4Interface> Function() _interfaces;
  late final Future<void> Function(List<RelayRegistration>) _configure;
  final _starts = <String, Object>{};
  final _targets = <String, RelayRegistration>{};

  static bool _linuxCanRelay() => Platform.isLinux && canCaptureRawPackets();

  @override
  bool appliesTo(Network network) =>
      udpBroadcastRelayRequested(network.flags) &&
      network.netNamespace == null &&
      network.additionalConfiguration['netns'] == null &&
      _available();

  @override
  Future<String?> start(String networkId, Network network) async {
    if (!appliesTo(network)) {
      await stop(networkId);
      return null;
    }
    final run = _starts[networkId] = Object();
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final assigned = await assignedAddress?.call(networkId);
        if (_starts[networkId] != run) return null;
        final address = network.dhcp && assignedAddress != null
            ? assigned
            : assigned ?? network.ipv4;
        final ipv4 = _ipv4(address);
        // Named TUNs can be shared. A DHCP instance must report which
        // address belongs to it before we use that link.
        final tun = network.dhcp && ipv4 == null
            ? null
            : findRelayTun(
                _interfaces(),
                name: network.flags.deviceName,
                address: ipv4,
              );
        if (tun != null) {
          _targets[networkId] = (
            target: relayTarget(networkId, tun),
            followsDhcp: network.dhcp,
          );
          await _publish();
          return _starts[networkId] == run ? tun.name : null;
        }
        if (attempt + 1 < attempts) await Future<void>.delayed(retryDelay);
        if (_starts[networkId] != run) return null;
      }
      if (_starts[networkId] == run && _targets.remove(networkId) != null) {
        await _stopTargets();
      }
      _log(
        'Could not find the TUN for UDP broadcast relay on ${network.networkName}',
      );
    } catch (error) {
      if (_starts[networkId] == run && _targets.remove(networkId) != null) {
        await _stopTargets();
      }
      _log(
        'Could not start UDP broadcast relay on ${network.networkName}: $error',
      );
    } finally {
      if (_starts[networkId] == run) _starts.remove(networkId);
    }
    return null;
  }

  Future<void> _publish() => _configure(_targets.values.toList());

  @override
  Future<void> stop(String networkId) async {
    _starts.remove(networkId);
    if (_targets.remove(networkId) == null) return;
    await _stopTargets();
  }

  @override
  Future<void> stopAll() async {
    _starts.clear();
    _targets.clear();
    await _stopTargets();
  }

  Future<void> _stopTargets() async {
    try {
      await _publish();
    } catch (error) {
      _log('Could not stop UDP broadcast relay: $error');
    }
  }
}

int? _ipv4(String? address) {
  final parsed = magicDnsIpAddress(address);
  if (parsed?.type != InternetAddressType.IPv4) return null;
  return ByteData.sublistView(parsed!.rawAddress).getUint32(0);
}

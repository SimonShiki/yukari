import 'dart:io';

import 'package:yukari_core/bindings/easytier_ffi_native.dart' as native;
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';
import 'android_vpn.dart';
import 'package:yukari_core/backend/ffi_backend.dart';

/// The VPN the app asks Android for on [network]'s behalf: the addresses
/// routed into the tunnel, and the Magic DNS server when the network asks for
/// it.
///
/// Android answers the Magic DNS server through the tunnel, so its address
/// needs a route of its own: EasyTier only receives the TUN file descriptor
/// here and never learns the interface to route through.
({String ipv4, int mtu, List<String> routes, String? dns}) androidVpnRequest(
  Network network,
) {
  final magicDns = magicDnsRequested(network.flags);
  return (
    ipv4: network.ipv4 ?? '10.144.144.1',
    mtu: 1420,
    routes: [
      if (network.ipv4 case final ipv4?)
        ipv4NetworkCidr(ipv4)
      else if (network.proxyNetworks.isEmpty)
        '10.144.144.0/24',
      for (final proxy in network.proxyNetworks) proxy.cidr,
      if (magicDns) '$magicDnsServer/32',
    ],
    dns: magicDns ? magicDnsServer : null,
  );
}

/// The IPv4 network [cidr] designates, with its host bits cleared.
///
/// Android's `VpnService.Builder.addRoute` rejects a route whose address has
/// host bits outside its prefix ("Bad address"), so a configured
/// `10.126.126.2/24` is routed as `10.126.126.0/24`. An address without a
/// prefix is taken as that host's `/24`; input the network editor never
/// allowed comes back unchanged, for the platform to report.
String ipv4NetworkCidr(String cidr) {
  final parts = cidr.split('/');
  final address = InternetAddress.tryParse(parts.first);
  final prefix = parts.length > 1 ? int.tryParse(parts[1]) : 24;
  if (parts.length > 2 ||
      address?.type != InternetAddressType.IPv4 ||
      prefix == null ||
      prefix < 0 ||
      prefix > 32) {
    return cidr;
  }
  final bits = address!.rawAddress.fold(0, (bits, byte) => bits << 8 | byte);
  final network = prefix == 0 ? 0 : bits & (0xFFFFFFFF << (32 - prefix));
  return '${network >> 24 & 0xFF}.${network >> 16 & 0xFF}'
      '.${network >> 8 & 0xFF}.${network & 0xFF}/$prefix';
}

/// Runs instances in process and routes their traffic through Android's
/// VpnService, which allows one VPN at a time.
class AndroidBackend extends FfiBackend {
  AndroidBackend({AndroidVpn? vpn}) : _vpn = vpn ?? systemAndroidVpn;

  /// The Android VPN the app drives: the method channel, or a test's recorder.
  final AndroidVpn _vpn;

  /// The instance whose TUN device the VPN service holds, or null.
  String? _vpnNetwork;

  /// Android holds one VPN, so one network may create a TUN device. Networks
  /// that run without one ([NetworkFlags.noTun]) take no slot.
  @override
  int? get maxTunInstances => 1;

  @override
  Future<void> start(String id, Network network) async {
    await super.start(id, network);
    if (network.flags.noTun) return;
    final request = androidVpnRequest(network);
    try {
      final fd = await _vpn.start(
        networkName: network.networkName,
        ipv4: request.ipv4,
        mtu: request.mtu,
        routes: request.routes,
        dns: request.dns,
      );
      await setTunFd(network.networkName, fd);
      _vpnNetwork = network.networkName;
    } catch (_) {
      await super.stop([network.networkName]);
      // The service may have come up before this interface failed: tear it
      // down only when no other network owns it, so a refused second start
      // cannot drop the first network's VPN.
      if (_vpnNetwork == null) await _stopVpnQuietly();
      rethrow;
    }
  }

  /// Stops [names] and, when one of them owns the VPN service, the VPN itself:
  /// a network that ran without a TUN device must not tear down the running
  /// network's VPN.
  @override
  Future<void> stop(List<String> names) async {
    await super.stop(names);
    if (!names.contains(_vpnNetwork)) return;
    await _vpn.stop();
    // Ownership is kept until the service is actually gone, so a stop that
    // throws leaves it to a later retry rather than abandoning a live VPN.
    _vpnNetwork = null;
  }

  @override
  Future<TunAccess> tunAccess(Network network) async =>
      network.flags.noTun || await _vpn.requestPermission()
      ? TunAccess.granted
      : TunAccess.denied;

  /// Releases the backend, tearing down a VPN service this backend still
  /// owns: its instance was already deleted when the stop that would have
  /// released the service failed, so nothing else would retry it.
  @override
  Future<void> dispose() async {
    if (_vpnNetwork != null) {
      await _stopVpnQuietly();
      // The service is released, so the stop [super.dispose] runs for whatever
      // EasyTier still lists must not ask for it again.
      _vpnNetwork = null;
    }
    await super.dispose();
  }

  /// Hands [instanceName] the TUN file descriptor [fd]. Overridable, so the
  /// backend can be driven without an EasyTier instance of that name.
  Future<void> setTunFd(String instanceName, int fd) async =>
      native.setTunFd(instanceName, fd);

  /// Tells Android to drop the VPN service, keeping the failure that caused
  /// the cleanup: that is the one the caller must see.
  Future<void> _stopVpnQuietly() async {
    try {
      await _vpn.stop();
    } catch (_) {
      // The service is stopping anyway; nothing is left to report it to.
    }
  }
}

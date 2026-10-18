import '../bindings/easytier_ffi_native.dart' as native;
import '../models/models.dart';
import '../system/magic_dns.dart';
import 'android_vpn.dart';
import 'ffi_backend.dart';

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
        ipv4.contains('/') ? ipv4 : '$ipv4/24'
      else if (network.proxyNetworks.isEmpty)
        '10.144.144.0/24',
      for (final proxy in network.proxyNetworks) proxy.cidr,
      if (magicDns) '$magicDnsServer/32',
    ],
    dns: magicDns ? magicDnsServer : null,
  );
}

/// Runs instances in process and routes their traffic through Android's
/// VpnService, which allows one VPN at a time.
class AndroidBackend extends FfiBackend {
  @override
  int? get maxInstances => 1;

  @override
  Future<void> start(String id, Network network) async {
    await super.start(id, network);
    if (network.flags.noTun) return;
    final request = androidVpnRequest(network);
    try {
      final fd = await AndroidVpnService.startVpn(
        networkName: network.networkName,
        ipv4: request.ipv4,
        mtu: request.mtu,
        routes: request.routes,
        dns: request.dns,
      );
      native.setTunFd(network.networkName, fd);
    } catch (_) {
      await super.stop([network.networkName]);
      rethrow;
    }
  }

  @override
  Future<void> stop(List<String> names) async {
    await super.stop(names);
    await AndroidVpnService.stopVpn();
  }

  @override
  Future<TunAccess> tunAccess(Network network) async =>
      network.flags.noTun || await AndroidVpnService.requestVpnPermission()
      ? TunAccess.granted
      : TunAccess.denied;
}

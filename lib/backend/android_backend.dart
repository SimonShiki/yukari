import '../bindings/easytier_ffi_native.dart' as native;
import '../models/models.dart';
import 'android_vpn.dart';
import 'ffi_backend.dart';

/// Runs instances in process and routes their traffic through Android's
/// VpnService, which allows one VPN at a time.
class AndroidBackend extends FfiBackend {
  @override
  int? get maxInstances => 1;

  @override
  Future<void> start(String id, Network network) async {
    await super.start(id, network);
    if (network.flags.noTun) return;
    try {
      final fd = await AndroidVpnService.startVpn(
        networkName: network.networkName,
        ipv4: network.ipv4 ?? '10.144.144.1',
        mtu: 1420,
        routes: _routes(network),
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

  static List<String> _routes(Network network) => [
    if (network.ipv4 case final ipv4?)
      ipv4.contains('/') ? ipv4 : '$ipv4/24'
    else if (network.proxyNetworks.isEmpty)
      '10.144.144.0/24',
    for (final proxy in network.proxyNetworks) proxy.cidr,
  ];
}

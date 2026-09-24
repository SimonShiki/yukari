import 'dart:io';
import 'package:yukari/bindings/easytier_ffi_native.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/utils/vpn_service_android.dart';

class AndroidNetworkRunner {
  /// Start a network instance on Android using VPN service
  static Future<void> runNetworkWithVpn(Network network) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidNetworkRunner is only for Android');
    }

    await runNetworkInstance(network);

    try {
      final routes = _buildRoutes(network);
      final tunFd = await AndroidVpnService.startVpn(
        networkName: network.networkName,
        ipv4: network.ipv4 ?? '10.144.144.1',
        mtu: 1420,
        routes: routes,
        dns: null,
      );

      setTunFd(network.networkName, tunFd);
    } catch (e) {
      await deleteNetworkInstances([network.networkName]);
      rethrow;
    }
  }

  static List<String> _buildRoutes(Network network) {
    final routes = <String>[];

    if (network.ipv4 != null) {
      final cidr = network.ipv4!.contains('/')
          ? network.ipv4!
          : '${network.ipv4!}/24';
      routes.add(cidr);
    }

    for (final proxyNetwork in network.proxyNetworks) {
      routes.add(proxyNetwork.cidr);
    }

    if (routes.isEmpty) {
      routes.add('10.144.144.0/24');
    }

    return routes;
  }
}

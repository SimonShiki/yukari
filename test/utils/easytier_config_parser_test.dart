import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/utils/easytier_config_parser.dart';
import 'package:yukari/utils/easytier_config_serializer.dart';

void main() {
  test('parses a config and groups peers by address', () {
    final network = parseEasyTierConfig('''
hostname = "box"
ipv4 = "10.144.144.2/24"
dhcp = false
listeners = ["tcp://0.0.0.0:11010"]

[network_identity]
network_name = "home"
network_secret = "s3cret"

[[peer]]
uri = "tcp://example.com:11010"

[[peer]]
uri = "udp://example.com:11010"

[flags]
mtu = 1400
''');

    expect(network.networkName, 'home');
    expect(network.networkSecret, 's3cret');
    expect(network.hostname, 'box');
    expect(network.dhcp, isFalse);
    expect(network.ipv4, '10.144.144.2/24');
    expect(network.listeners.single.toString(), 'tcp://0.0.0.0:11010');
    expect(network.flags.mtu, 1400);
    final node = network.nodes.single;
    expect(node.id, 'example.com:11010');
    expect(node.protocols, [NodeProtocol.tcp, NodeProtocol.udp]);

    final roundTrip = parseEasyTierConfig(network.toEasyTierToml());
    expect(
      roundTrip.toJson()
        ..remove('createdAt')
        ..remove('updatedAt'),
      network.toJson()
        ..remove('createdAt')
        ..remove('updatedAt'),
    );
  });

  test('omits empty lists that EasyTier reads as overrides', () {
    final toml = Network().toEasyTierToml();
    for (final key in [
      'routes',
      'stun_servers',
      'tcp_stun_servers',
      'stun_servers_v6',
    ]) {
      expect(toml, isNot(contains('$key =')));
    }
  });

  test('keeps a disabled VPN portal and treats a missing state as enabled', () {
    final network = Network()
      ..vpnPortal = VpnPortal(wireguardListen: '0.0.0.0:22022', enabled: false);
    expect(
      parseEasyTierConfig(network.toEasyTierToml()).vpnPortal!.enabled,
      isFalse,
    );

    final legacy = parseEasyTierConfig('''
[vpn_portal_config]
wireguard_listen = "0.0.0.0:22022"
''');
    expect(legacy.vpnPortal!.enabled, isTrue);
  });
}

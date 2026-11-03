import 'package:toml/toml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/utils/easytier_config_parser.dart';
import 'package:yukari_core/utils/easytier_config_serializer.dart';

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
    expect(node.url.toString(), 'example.com');
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

  test('parses and exports an EasyTier DHCP IPv4 subnet', () {
    final network = parseEasyTierConfig('''
dhcp = "192.168.100.0/24"
''');

    expect(network.dhcp, isTrue);
    expect(network.dhcpIpv4Cidr, '192.168.100.0/24');
    final exported = TomlDocument.parse(network.toEasyTierToml()).toMap();
    expect(exported['dhcp'], '192.168.100.0/24');
    expect(
      parseEasyTierConfig(network.toEasyTierToml()).dhcpIpv4Cidr,
      '192.168.100.0/24',
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

  test('preserves unknown top-level and flag values through an export', () {
    const content = '''
vendor_setting = { mode = "fast", values = [1, 2.5, true] }
vendor_list = ["a", "b"]

[flags]
future_flag = { enabled = true, names = ["one", "two"] }
''';
    final network = parseEasyTierConfig(content);

    expect(network.additionalConfiguration, {
      'vendor_setting': {
        'mode': 'fast',
        'values': [1, 2.5, true],
      },
      'vendor_list': ['a', 'b'],
    });
    expect(network.additionalFlags, {
      'future_flag': {
        'enabled': true,
        'names': ['one', 'two'],
      },
    });

    final exported = TomlDocument.parse(network.toEasyTierToml()).toMap();
    expect(
      exported['vendor_setting'],
      network.additionalConfiguration['vendor_setting'],
    );
    expect(exported['vendor_list'], ['a', 'b']);
    expect(
      (exported['flags'] as Map)['future_flag'],
      network.additionalFlags['future_flag'],
    );
    expect(
      parseEasyTierConfig(network.toEasyTierToml()).additionalFlags,
      network.additionalFlags,
    );
  });
}

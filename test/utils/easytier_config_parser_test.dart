import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/node.dart';
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
}

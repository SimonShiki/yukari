import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/node.dart';

void main() {
  test('stores only a name, full URL and optional public key', () {
    final node = Node(
      name: 'Local websocket',
      url: Uri.parse('http://localhost:11451/ws?transport=websocket'),
      publicKey: 'key',
    );
    expect(node.toJson(), {
      'name': 'Local websocket',
      'url': 'http://localhost:11451/ws?transport=websocket',
      'publicKey': 'key',
    });
    expect(node.copy().toJson(), node.toJson());
  });

  test('connection identity distinguishes schemes, paths and queries', () {
    final node = Node(name: 'A', url: Uri.parse('ws://localhost:11451/ws'));
    expect(sameNode(node, node.copy()..name = 'B'), isTrue);
    for (final url in [
      'http://localhost:11451/ws',
      'ws://localhost:11451/other',
      'ws://localhost:11451/ws?route=two',
    ]) {
      expect(sameNode(node, node.copy()..url = Uri.parse(url)), isFalse);
    }
    expect(sameNode(node, node.copy()..publicKey = 'pin'), isTrue);
  });

  test('expands every legacy protocol and keeps paths, IPv6 and keys', () {
    final network = Network.fromJson({
      ...Network().toJson(),
      'nodes': [
        {
          'id': 'Old relay',
          'url': 'wss://[2001:db8::1]/ws',
          'port': 8787,
          'protocols': ['tcp', 'wss'],
          'publicKey': 'key',
        },
      ],
    });
    expect(network.nodes.map((node) => node.url.toString()), [
      'tcp://[2001:db8::1]:8787/ws',
      'wss://[2001:db8::1]:8787/ws',
    ]);
    expect(network.nodes.first.name, 'Old relay');
    expect(network.nodes.map((node) => node.publicKey), everyElement('key'));
    expect(network.copy().toJson(), network.toJson());
  });
}

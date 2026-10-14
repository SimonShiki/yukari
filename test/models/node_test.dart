import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/node.dart';

void main() {
  test('a peer host is stored and shown without an authority slash', () {
    final url = nodeUrlForHost('47.103.14.110');

    expect(url.toString(), '47.103.14.110');
    expect(nodeHost(url), '47.103.14.110');
    expect(nodeUrlText(url), '47.103.14.110');
  });

  test('an IPv6 peer keeps the bracketed form it parses back from', () {
    final url = nodeUrlForHost('2001:db8::1');

    expect(url.toString(), '//[2001:db8::1]');
    expect(nodeHost(url), '2001:db8::1');
    expect(nodeUrlText(url), '//[2001:db8::1]');
    expect(Uri.parse(nodeUrlText(url)).host, '2001:db8::1');
  });

  test('an address with a scheme or a path keeps its full form', () {
    expect(
      nodeUrlText(Uri.parse('wss://relay.example.com/ws')),
      'wss://relay.example.com/ws',
    );
    // A URL an older import stored as `//host` reads back clean.
    expect(nodeUrlText(Uri(host: '47.103.14.110')), '47.103.14.110');
  });

  test('the stored form still builds the endpoint EasyTier is given', () {
    final node = Node(
      id: 'relay',
      url: nodeUrlForHost('47.103.14.110'),
      port: 11010,
      protocols: const [NodeProtocol.tcp],
    );

    expect(
      node.endpoint(NodeProtocol.tcp).toString(),
      'tcp://47.103.14.110:11010',
    );
  });
}

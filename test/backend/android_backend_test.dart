import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/android_backend.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/system/magic_dns.dart';

Network _network({
  bool acceptDns = true,
  bool noTun = false,
  String? ipv4,
  List<String> proxyCidrs = const [],
}) => Network()
  ..networkName = 'alpha'
  ..ipv4 = ipv4
  ..proxyNetworks = [
    for (final cidr in proxyCidrs) ProxyNetwork(cidr: cidr),
  ]
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun);

void main() {
  group('androidVpnRequest', () {
    test('a Magic DNS network gets the server and a route to it', () {
      final request = androidVpnRequest(_network());

      expect(request.dns, magicDnsServer);
      expect(request.routes, ['10.144.144.0/24', '100.100.100.101/32']);
    });

    test('a network without Magic DNS gets neither', () {
      final request = androidVpnRequest(_network(acceptDns: false));

      expect(request.dns, isNull);
      expect(request.routes, ['10.144.144.0/24']);
    });

    test('a network without a TUN gets neither', () {
      final request = androidVpnRequest(_network(noTun: true));

      expect(request.dns, isNull);
      expect(request.routes, ['10.144.144.0/24']);
    });

    test('the configured address, MTU and proxy networks are unchanged', () {
      final request = androidVpnRequest(
        _network(ipv4: '10.126.126.1/24', proxyCidrs: ['192.168.1.0/24']),
      );

      expect(request.ipv4, '10.126.126.1/24');
      expect(request.mtu, 1420);
      expect(request.routes, [
        '10.126.126.1/24',
        '192.168.1.0/24',
        '100.100.100.101/32',
      ]);
    });

    test('an address without a prefix becomes its /24', () {
      final request = androidVpnRequest(_network(ipv4: '10.126.126.1'));

      expect(request.routes, ['10.126.126.1/24', '100.100.100.101/32']);
    });
  });

  test('magicDnsRequested is the accept-DNS flag without a TUN exception', () {
    expect(magicDnsRequested(_network().flags), isTrue);
    expect(magicDnsRequested(_network(acceptDns: false).flags), isFalse);
    expect(magicDnsRequested(_network(noTun: true).flags), isFalse);
  });
}

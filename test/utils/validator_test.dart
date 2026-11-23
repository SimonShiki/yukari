import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_components.dart';
import 'package:yukari_core/utils/dns_name.dart';
import 'package:yukari/utils/validator.dart';

void main() {
  test('network name must be non-empty and unique', () {
    expect(validateNetworkName('alpha', ['beta']), isNull);
    expect(validateNetworkName('  ', []), isNotNull);
    expect(validateNetworkName('beta', ['beta']), isNotNull);
    expect(validateNetworkName(' beta ', ['beta']), isNotNull);
  });

  test('hostname is limited to 32 characters', () {
    expect(validateHostname(''), isNull);
    expect(validateHostname('a' * 32), isNull);
    expect(validateHostname('a' * 33), isNotNull);
  });

  test('CIDR must match the address family', () {
    const v4 = InternetAddressType.IPv4;
    const v6 = InternetAddressType.IPv6;
    expect(validateCidr('', v4), isNull);
    expect(validateCidr('10.144.144.1/24', v4), isNull);
    expect(validateCidr('10.144.144.1', v4), isNotNull);
    expect(validateCidr('10.144.144.1/33', v4), isNotNull);
    expect(validateCidr('300.1.1.1/24', v4), isNotNull);
    expect(validateCidr('fd00::1/64', v4), isNotNull);
    expect(validateCidr('fd00::1/64', v6), isNull);
    expect(validateCidr('fd00::1/129', v6), isNotNull);
    expect(validateCidr('10.0.0.1/8', v6), isNotNull);
  });

  test('integer ranges reject non-numbers and out-of-range values', () {
    expect(validatePort('11010'), isNull);
    expect(validatePort(''), isNotNull);
    expect(validatePort('0'), isNotNull);
    expect(validatePort('65536'), isNotNull);
    expect(validatePort('abc'), isNotNull);
    expect(validateIntRange('576', 'MTU', 576, 65535), isNull);
    expect(validateIntRange('575', 'MTU', 576, 65535), isNotNull);
  });

  test('hosts are IP addresses or DNS names', () {
    expect(validateHost('0.0.0.0'), isNull);
    expect(validateHost('::'), isNull);
    expect(validateHost('example.com'), isNull);
    expect(validateHost(''), isNotNull);
    expect(validateHost('exa mple.com'), isNotNull);
    expect(validateHost('-bad.com'), isNotNull);
    expect(validateHost('a/b'), isNotNull);
  });

  test('node URLs contain a scheme, host and port and preserve subpaths', () {
    expect(validateNodeUrl('example.com'), isNotNull);
    expect(validateNodeUrl('wss://example.com/path'), isNull);
    expect(validateNodeUrl('1.2.3.4'), isNotNull);
    expect(validateNodeUrl('http://localhost:11451/ws'), isNull);
    expect(validateNodeUrl('wss://[2001:db8::1]/ws?route=one'), isNull);
    expect(validateNodeUrl('tcp://example.com'), isNotNull);
    expect(validateNodeUrl('tcp://example.com:65536'), isNotNull);
    expect(validateNodeUrl('ws://example.com:0/ws'), isNotNull);
    expect(validateNodeUrl('ws://example.com/ws#fragment'), isNotNull);
    expect(validateNodeUrl(''), isNotNull);
    expect(validateNodeUrl('example.com:11010'), isNotNull);
    expect(validateNodeUrl('tcp://example.com:11010'), isNull);
    expect(validateNodeUrl('example.com?a=b'), isNotNull);
    expect(validateNodeUrl('example.com/path'), isNotNull);
  });

  test('SOCKS5 proxy needs scheme, host and port', () {
    expect(validateSocks5Proxy(''), isNull);
    expect(validateSocks5Proxy('socks5://127.0.0.1:1080'), isNull);
    expect(validateSocks5Proxy('socks5://127.0.0.1'), isNotNull);
    expect(validateSocks5Proxy('http://127.0.0.1:1080'), isNotNull);
    expect(validateSocks5Proxy('127.0.0.1:1080'), isNotNull);
  });

  test('STUN servers are validated line by line', () {
    expect(validateLines('', validateStunServer), isNull);
    expect(
      validateLines('stun.example.com:3478\n\n1.2.3.4', validateStunServer),
      isNull,
    );
    expect(validateLines('[::1]:3478', validateStunServer), isNull);
    expect(
      validateLines('stun.example.com:99999', validateStunServer),
      isNotNull,
    );
    expect(
      validateLines('ok.com\nbad host', validateStunServer),
      contains('bad host'),
    );
  });

  test('IPv4 networks have no host bits', () {
    expect(validateIpv4Network('10.0.0.0/24'), isNull);
    expect(validateIpv4Network('0.0.0.0/0'), isNull);
    expect(validateIpv4Network('10.0.0.1/24'), isNotNull);
    expect(validateIpv4Network('fd00::/64'), isNotNull);
    expect(validateIpv4Network('10.0.0.0'), isNotNull);
  });

  test('DHCP IPv4 subnets have usable host space', () {
    expect(validateDhcpIpv4Cidr('192.168.100.0/24'), isNull);
    expect(validateDhcpIpv4Cidr('0.0.0.0/0'), isNull);
    expect(validateDhcpIpv4Cidr('192.168.100.1/24'), isNotNull);
    expect(validateDhcpIpv4Cidr('192.168.100.0/31'), isNotNull);
    expect(
      validateNetwork(Network()..dhcpIpv4Cidr = '192.168.100.0/31'),
      isNotNull,
    );
  });

  test('IPv6 networks and DHCPv6 subnets validate prefix and host bits', () {
    expect(validateIpv6Network('fd00::/64'), isNull);
    expect(validateIpv6Network('fd00::1/64'), isNotNull);
    expect(validateIpv6Network('::/0'), isNull);

    expect(validateDhcpIpv6Cidr(''), isNull);
    expect(validateDhcpIpv6Cidr('fd6b:8c2d:91e4::/64'), isNull);
    expect(validateDhcpIpv6Cidr('fd6b:8c2d:91e4::1/64'), isNotNull);
    expect(validateDhcpIpv6Cidr('fd6b:8c2d:91e4::/127'), isNotNull);
    expect(
      validateNetwork(Network()..dhcpIpv6Cidr = 'fd6b:8c2d:91e4::/127'),
      isNotNull,
    );
  });

  test('DNS origins, record names, values and TTLs validate rules', () {
    expect(
      validateDnsOrigin('example.test.', existingOrigins: ['other.test']),
      isNull,
    );
    expect(validateDnsOrigin(''), isNotNull);
    expect(validateDnsOrigin('.'), isNotNull);
    expect(
      validateDnsOrigin('example.test', existingOrigins: ['EXAMPLE.TEST.']),
      isNotNull,
    );

    expect(validateDnsRecordName('@'), isNull);
    expect(validateDnsRecordName('*'), isNull);
    expect(validateDnsRecordName('*.svc'), isNull);
    expect(validateDnsRecordName('_sip._tcp'), isNull);
    expect(validateDnsRecordName('nas'), isNull);
    expect(validateDnsRecordName(''), isNotNull);
    expect(validateDnsRecordName('bad..name'), isNotNull);
    expect(validateDnsRecordName('*.'), isNotNull);
    expect(validateDnsRecordName('${'a' * 64}.test'), isNotNull);
    expect(validateDnsOrigin('${'a' * 64}.test'), isNotNull);
    expect(
      validateDnsOrigin('${List.filled(4, 'a' * 63).join('.')}.test'),
      isNotNull,
    );
    expect(
      validateDnsOrigin(
        'new.test.',
        existingOrigins: [
          for (var index = 0; index < maxStaticDnsZones; index++)
            'zone$index.test.',
        ],
      ),
      isNotNull,
    );

    expect(validateDnsRecordValue('10.0.0.8', DnsRecordType.a), isNull);
    expect(validateDnsRecordValue('fd00::8', DnsRecordType.a), isNotNull);
    expect(validateDnsRecordValue('fd00::8', DnsRecordType.aaaa), isNull);
    expect(validateDnsRecordValue('10.0.0.8', DnsRecordType.aaaa), isNotNull);
    expect(validateDnsRecordValue('"hello world"', DnsRecordType.txt), isNull);
    expect(validateDnsRecordValue('   ', DnsRecordType.txt), isNotNull);
    expect(validateDnsRecordValue('bad mx', DnsRecordType.mx), isNotNull);
    expect(
      validateDnsRecordValue('10 mail.example.test.', DnsRecordType.mx),
      isNull,
    );
    expect(
      validateDnsRecordValue('10 5 5060 target', DnsRecordType.srv),
      isNull,
    );
    expect(
      validateDnsRecordValue('10 5 70000 target', DnsRecordType.srv),
      isNotNull,
    );
    expect(validateDnsRecordValue('plain text', DnsRecordType.txt), isNotNull);
    expect(
      validateDnsRecordValue('bad..target', DnsRecordType.cname),
      isNotNull,
    );
    expect(
      validateDnsRecordValue('target.example.test.', DnsRecordType.cname),
      isNull,
    );
    expect(validateDnsRecordValue('bad..target', DnsRecordType.ptr), isNotNull);
    expect(
      validateDnsRecordValue('"${'a' * 256}"', DnsRecordType.txt),
      isNotNull,
    );
    expect(
      validateDnsRecordValue(
        'ns.test. hostmaster.test. 1 2 3 4 5',
        DnsRecordType.soa,
      ),
      isNull,
    );
    expect(
      validateDnsRecordValue(
        'ns.test. hostmaster.test. one 2 3 4 5',
        DnsRecordType.soa,
      ),
      isNotNull,
    );
    expect(
      validateDnsZones([
        for (var index = 0; index < 17; index++)
          DnsZone(origin: 'zone$index.test.'),
      ]),
      isNotNull,
    );

    expect(validateDnsTtl(''), isNull);
    expect(validateDnsTtl('0'), isNull);
    expect(validateDnsTtl('120'), isNull);
    expect(validateDnsTtl('-1'), isNotNull);

    final dupNetwork = Network()
      ..dns = DnsConfig(
        zones: [
          DnsZone(origin: 'example.test.'),
          DnsZone(origin: 'example.test'),
        ],
      );
    expect(validateNetwork(dupNetwork), isNotNull);
  });

  test('proxy networks map only to networks of the same size', () {
    expect(validateProxyNetwork('192.168.1.0/24'), isNull);
    expect(validateProxyNetwork('192.168.1.0/24->10.1.1.0/24'), isNull);
    expect(validateProxyNetwork('192.168.1.0/24->10.1.0.0/16'), isNotNull);
    expect(validateProxyNetwork('192.168.1.0/24->bad'), isNotNull);
  });

  test('socket addresses need an IP and a port', () {
    expect(validateSocketAddress('0.0.0.0:22022'), isNull);
    expect(validateSocketAddress('[::]:22022'), isNull);
    expect(validateSocketAddress('::1:22022'), isNotNull);
    expect(validateSocketAddress('example.com:22022'), isNotNull);
    expect(validateSocketAddress('0.0.0.0'), isNotNull);
  });

  test('port forwards name protocol, bind and destination', () {
    expect(validatePortForward('udp://0.0.0.0:12345/10.1.1.2:23456'), isNull);
    expect(validatePortForward('tcp://[::]:80/[fd00::2]:8080'), isNull);
    expect(validatePortForward('icmp://0.0.0.0:1/10.1.1.2:1'), isNotNull);
    expect(validatePortForward('tcp://0.0.0.0:80'), isNotNull);
  });

  test('port whitelists take ports and ascending ranges', () {
    expect(validatePortRange('80'), isNull);
    expect(validatePortRange('8000-9000'), isNull);
    expect(validatePortRange('9000-8000'), isNotNull);
    expect(validatePortRange('70000'), isNotNull);
    expect(validatePortRange('http'), isNotNull);
  });

  test('private keys are base64-encoded 32-byte values', () {
    expect(validatePrivateKey(''), isNull);
    expect(validatePrivateKey('A' * 43 + '='), isNull);
    expect(validatePrivateKey('AAAA'), isNotNull);
    expect(validatePrivateKey('not base64!'), isNotNull);
  });

  test('whole networks are checked with the same rules as the editor', () {
    expect(validateNetwork(Network()), isNull);
    expect(validateNetwork(Network()..ipv4 = 'not-an-ip'), isNotNull);
    expect(validateNetwork(Network()..flags.mtu = 10), isNotNull);
    expect(validateNetwork(Network()..stunServers = ['bad host']), isNotNull);
    expect(validateNetwork(Network()..routes = ['10.0.0.1/8']), isNotNull);
    expect(validateNetwork(Network()..udpWhitelist = ['x']), isNotNull);
  });
}

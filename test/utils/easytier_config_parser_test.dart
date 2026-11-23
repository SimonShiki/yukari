import 'package:toml/toml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/bindings/easytier_ffi_native.dart' as ffi;
import 'package:yukari_core/models/models.dart';
import 'package:yukari/utils/easytier_config_parser.dart';
import 'package:yukari_core/utils/easytier_config_serializer.dart';

void main() {
  test('parses one connection per full peer URL', () {
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
    final node = network.nodes.first;
    expect(node.name, 'tcp://example.com:11010');
    expect(node.url.toString(), 'tcp://example.com:11010');
    expect(network.nodes.last.url.toString(), 'udp://example.com:11010');

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

  test('round-trips full URLs without merging schemes or subpaths', () {
    final urls = [
      'http://localhost:11451/ws',
      'ws://localhost:11451/ws?route=one',
      'ws://localhost:11451/other',
      'wss://[2001:db8::1]/ws',
    ];
    final network = parseEasyTierConfig(
      [
        for (final url in urls)
          '[[peer]]\nuri = "$url"\npeer_public_key = "pin"',
      ].join('\n'),
    );
    expect(network.nodes.map((node) => node.url.toString()), urls);
    final exported = TomlDocument.parse(network.toEasyTierToml()).toMap();
    expect(
      (exported['peer'] as List).map((peer) => (peer as Map)['uri']),
      urls,
    );
    expect(network.nodes.map((node) => node.publicKey), everyElement('pin'));
    final imported = parseEasyTierConfig(network.toEasyTierToml());
    expect(imported.nodes.map((node) => node.url.toString()), urls);
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

  test('round-trips LZO, UDP FEC, DHCPv6, and expanded Magic DNS zones', () {
    final network = Network()
      ..networkName = 'fec-dns-net'
      ..dhcp = true
      ..dhcpIpv4Cidr = '10.20.0.0/24'
      ..dhcpv6 = true
      ..dhcpIpv6Cidr = 'fd42:1234::/64'
      ..flags.compressionAlgorithm = CompressionAlgorithm.lzo
      ..flags.enableUdpFec = true
      ..flags.enableUdpFecKcp = true
      ..flags.enableUdpFecQuic = true
      ..flags.acceptDns = true
      ..flags.dnsZone = 'mesh.test.'
      ..dns = DnsConfig(
        domain: 'mesh.test.',
        zones: [
          DnsZone(
            origin: 'example.test.',
            ttl: 60,
            records: [
              DnsRecord(name: 'nas', type: DnsRecordType.a, value: '10.0.0.8'),
              DnsRecord(
                name: 'v6',
                type: DnsRecordType.aaaa,
                value: 'fd00::8',
                ttl: 120,
              ),
              DnsRecord(
                name: 'info',
                type: DnsRecordType.txt,
                value: '"local records"',
              ),
              DnsRecord(
                name: '@',
                type: DnsRecordType.mx,
                value: '10 mail.example.test.',
              ),
              DnsRecord(
                name: '_sip._tcp',
                type: DnsRecordType.srv,
                value: '10 5 5060 sip.example.test.',
              ),
            ],
          ),
        ],
      );

    final toml = network.toEasyTierToml();
    // Deprecated tld_dns_zone is omitted when [dns].domain is emitted.
    expect(toml, isNot(contains('tld_dns_zone')));

    // Validate against the real EasyTier FFI parser (45a6b6f1).
    ffi.parseConfig(toml);

    final roundTrip = parseEasyTierConfig(toml);
    expect(roundTrip.dhcpv6, isTrue);
    expect(roundTrip.dhcpIpv6Cidr, 'fd42:1234::/64');
    expect(roundTrip.flags.compressionAlgorithm, CompressionAlgorithm.lzo);
    expect(roundTrip.flags.enableUdpFec, isTrue);
    expect(roundTrip.flags.enableUdpFecKcp, isTrue);
    expect(roundTrip.flags.enableUdpFecQuic, isTrue);
    expect(roundTrip.flags.dnsZone, 'mesh.test.');
    expect(roundTrip.effectiveDnsDomain, 'mesh.test.');
    expect(roundTrip.dns?.domain, 'mesh.test.');
    final zone = roundTrip.dns!.zones.single;
    expect(zone.origin, 'example.test.');
    expect(zone.ttl, 60);
    expect(zone.records, hasLength(5));
    expect(zone.records[1].ttl, 120);
    expect(zone.records[2].type, DnsRecordType.txt);
    expect(zone.records[2].value, '"local records"');
  });

  test('migrates legacy flags.tld_dns_zone when [dns] is absent', () {
    final network = parseEasyTierConfig('''
dhcpv6 = true

[flags]
tld_dns_zone = "legacy.test."
data_compress_algo = "lzo"
''');
    expect(network.dhcpv6, isTrue);
    expect(network.dhcpIpv6Cidr, isNull);
    expect(network.flags.compressionAlgorithm, CompressionAlgorithm.lzo);
    expect(network.flags.dnsZone, 'legacy.test.');
    expect(network.effectiveDnsDomain, 'legacy.test.');

    final reExported = network.toEasyTierToml();
    ffi.parseConfig(reExported);
    final reparsed = parseEasyTierConfig(reExported);
    expect(reparsed.effectiveDnsDomain, 'legacy.test.');
  });
}

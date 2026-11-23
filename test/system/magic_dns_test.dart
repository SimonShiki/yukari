import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';

import '../fake_system_command.dart';

void main() {
  group('other platforms', () {
    test('have no system DNS support and run nothing', () async {
      final command = FakeSystemCommand();
      final system = MagicDnsSystem(
        platform: MagicDnsPlatform.other,
        command: command,
      );

      final probe = await system.probe(zone: 'et.net.', interfaceName: '');
      await system.apply(zone: 'et.net.', interfaceName: '');
      await system.reset(interfaceName: 'et_12_xoih', zone: 'et.net.');

      expect(system.supported, isFalse);
      expect(probe.state, MagicDnsState.unsupported);
      expect(probe.interface, isNull);
      expect(command.runs, isEmpty);
    });
  });

  group('interface discovery', () {
    const address = '10.126.126.2/24';

    test('configured TUN name is preferred over virtual IPv4 lookup', () async {
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) {
          if (executable == 'ip' && arguments.join(' ') == 'link show mytun') {
            return ok('mytun: <POINTOPOINT,UP,LOWER_UP>');
          }
          return androidHost()(executable, arguments);
        },
      );

      final probe = await androidSystem(command).probe(
        zone: 'et.net.',
        interfaceName: 'mytun',
        address: address,
      );

      expect(probe.interface, 'mytun');
      expect(command.runs.first.$2, ['link', 'show', 'mytun']);
    });

    test('resolves interface from virtual IPv4 and ignores route lookup', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(configured: () => true, jump: () => true),
      );

      final probe = await androidSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      expect(probe.state, MagicDnsState.configured);
      expect(probe.interface, 'et_12_xoih');
      expect(command.runs.first.$2, [
        '-4',
        '-o',
        'addr',
        'show',
        'to',
        '10.126.126.2',
      ]);
      expect(
        command.runs.any((run) => run.$1 == 'ip' && run.$2.contains('route')),
        isFalse,
      );
    });
  });

  group('helpers', () {
    test('zone helpers strip the trailing dot and format names', () {
      expect(magicDnsZoneBase('et.net.'), 'et.net');
      expect(magicDnsZoneBase('corp'), 'corp');
      expect(magicDnsNameOf(host: 'laptop', zone: 'et.net.'), 'laptop.et.net');
    });

    test('magicDnsIpv4Host parses IPv4 CIDRs and rejects invalid input', () {
      expect(magicDnsIpv4Host('10.126.126.2/24'), '10.126.126.2');
      expect(magicDnsIpv4Host('10.126.126.2'), '10.126.126.2');
      expect(magicDnsIpv4Host('fd00::1/64'), isNull);
      expect(magicDnsIpv4Host('not-an-ip'), isNull);
      expect(magicDnsIpv4Host(null), isNull);
    });

    test('magicDnsRequested requires acceptDns without noTun', () {
      expect(magicDnsRequested(NetworkFlags()..acceptDns = true), isTrue);
      expect(
        magicDnsRequested(
          NetworkFlags()
            ..acceptDns = true
            ..noTun = true,
        ),
        isFalse,
      );
      expect(magicDnsRequested(NetworkFlags()..acceptDns = false), isFalse);
    });
  });
}

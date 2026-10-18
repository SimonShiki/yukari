import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/backend/privilege.dart';
import 'package:yukari_core/system/magic_dns.dart';

import '../fake_system_command.dart';

void main() {
  group('Linux probe', () {
    const address = '10.126.126.2/24';

    test('a configured link reports configured and its interface', () async {
      final command = FakeSystemCommand(
        runHandler: linuxHost(configured: () => true),
      );

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      expect(probe.state, MagicDnsState.configured);
      expect(probe.interface, 'et_12_xoih');
      expect(command.elevated, isEmpty);
    });

    test('an unconfigured link reports missing', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      expect(probe.state, MagicDnsState.missing);
      expect(probe.interface, 'et_12_xoih');
    });

    test("another VPN's route to the Magic DNS server is not the link", () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      // The other VPN's TUN still carries the zone the service applied to it;
      // this network's own TUN is what the probe has to read.
      expect(probe.state, MagicDnsState.missing);
      expect(probe.interface, 'et_12_xoih');
      expect(command.runs.first.$2, [
        '-4',
        '-o',
        'addr',
        'show',
        'to',
        '10.126.126.2',
      ]);
    });

    test('a configured TUN name is preferred over the address', () async {
      final command = FakeSystemCommand(runHandler: linuxHost(named: 'mytun'));

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: 'mytun',
        address: address,
      );

      expect(probe.interface, 'mytun');
      expect(command.runs.first.$2, ['link', 'show', 'mytun']);
    });

    test('a missing interface reports noInterface', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: 'gone',
        address: '10.9.9.9/24',
      );

      expect(probe.state, MagicDnsState.noInterface);
      expect(probe.interface, isNull);
    });

    test('no name and no address identify nothing', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
      );

      expect(probe.state, MagicDnsState.noInterface);
      expect(command.runs, isEmpty, reason: 'no hint names an EasyTier link');
    });

    test('a host without resolvectl reports unsupported', () async {
      final command = FakeSystemCommand(
        runHandler: linuxHost(resolvectl: false),
      );

      final probe = await linuxSystem(command).probe(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      expect(probe.state, MagicDnsState.unsupported);
      expect(probe.interface, 'et_12_xoih');
    });
  });

  group('Linux apply and reset', () {
    const address = '10.126.126.2/24';

    test('apply authors one elevated shell command for both steps', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      await linuxSystem(command).apply(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      final (executable, arguments) = command.elevated.single;
      expect(executable, 'sh');
      expect(arguments.first, '-c');
      expect(
        arguments.last,
        contains("resolvectl dns 'et_12_xoih' 100.100.100.101"),
      );
      expect(
        arguments.last,
        contains("resolvectl domain 'et_12_xoih' '~et.net'"),
      );
    });

    test("apply never points another VPN's TUN at the Magic DNS server", () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      await linuxSystem(command).apply(
        zone: 'et.net.',
        interfaceName: '',
        address: address,
      );

      expect(command.elevated.single.$2.last, contains("'et_12_xoih'"));
      expect(command.elevated.single.$2.last, isNot(contains('FlClash')));
    });

    test('apply fails closed when no EasyTier interface is identified', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      await linuxSystem(command).apply(
        zone: 'et.net.',
        interfaceName: '',
        address: '10.9.9.9/24',
      );

      expect(command.elevated, isEmpty);
    });

    test('apply rejects a zone or interface unsafe for a shell', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());
      final system = linuxSystem(command);

      await expectLater(
        system.apply(
          zone: 'et.net; touch /tmp/pwned',
          interfaceName: 'eth0',
          address: address,
        ),
        throwsArgumentError,
      );
      await expectLater(
        system.apply(
          zone: 'et.net.',
          interfaceName: "eth0'; touch /tmp/x; '",
          address: address,
        ),
        throwsArgumentError,
      );
      expect(command.elevated, isEmpty);
    });

    test('a dismissed elevation surfaces the failure', () async {
      final command = FakeSystemCommand(
        runHandler: linuxHost(),
        elevateHandler: (_, _) async =>
            throw const ElevationException('Authorization was dismissed'),
      );

      await expectLater(
        linuxSystem(command).apply(
          zone: 'et.net.',
          interfaceName: 'et_12_xoih',
        ),
        throwsA(isA<ElevationException>()),
      );
    });

    test('reset reverts the interface', () async {
      final command = FakeSystemCommand();

      await linuxSystem(command).reset(interfaceName: 'et_12_xoih');

      expect(command.elevated.single.$1, 'resolvectl');
      expect(command.elevated.single.$2, ['revert', 'et_12_xoih']);
    });

    test('reset rejects an unsafe interface name', () async {
      final command = FakeSystemCommand();

      await expectLater(
        linuxSystem(command).reset(interfaceName: 'eth0 && reboot'),
        throwsArgumentError,
      );
      expect(command.elevated, isEmpty);
    });
  });

  group('Windows', () {
    test('Windows configures its own DNS, and the probe only reads', () async {
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) => ok(
          'Ethernet adapter EasyTier:\n'
          '   DNS Servers . . . . . . . . . . . : 100.100.100.101\n',
        ),
      );
      final system = windowsSystem(command);

      expect(system.automatic, isTrue);
      expect(system.configurable, isFalse);
      final probe = await system.probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.configured);
      expect(probe.interface, isNull);
      expect(command.elevated, isEmpty);
      expect(command.runs.single.$1, 'ipconfig');
    });

    test('an ipconfig without the server reports missing', () async {
      final command = FakeSystemCommand(
        runHandler: (_, _) => ok('DNS Servers: 8.8.8.8'),
      );

      final probe = await windowsSystem(command)
          .probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.missing);
    });
  });

  group('other platforms', () {
    test('have no system DNS support and run nothing', () async {
      final command = FakeSystemCommand();
      final system = MagicDnsSystem(
        platform: MagicDnsPlatform.other,
        command: command,
      );

      final probe = await system.probe(zone: 'et.net.', interfaceName: '');

      expect(system.supported, isFalse);
      expect(probe.state, MagicDnsState.unsupported);
      expect(command.runs, isEmpty);
      expect(
        system.manualCommands(zone: 'et.net.', interfaceName: ''),
        isEmpty,
      );
    });
  });

  group('manual fallback', () {
    test('spells the resolvectl commands for the discovered interface', () {
      final system = linuxSystem(FakeSystemCommand());

      expect(system.manualCommands(zone: 'et.net.', interfaceName: 'et_12'), [
        'sudo resolvectl dns et_12 100.100.100.101',
        'sudo resolvectl domain et_12 ~et.net',
      ]);
      expect(
        system.manualCommands(zone: 'et.net.', interfaceName: ''),
        contains('sudo resolvectl dns <easytier-tun> 100.100.100.101'),
      );
    });

    test('spells the resolv.conf lines for a host without resolved', () {
      final system = linuxSystem(FakeSystemCommand());

      expect(system.resolvConfLines(zone: 'et.net.'), [
        'nameserver 100.100.100.101',
        'search et.net',
      ]);
    });

    test('gives Windows a direct query to test the server', () {
      final system = windowsSystem(FakeSystemCommand());

      expect(
        system.manualCommands(zone: 'et.net.', interfaceName: ''),
        contains('nslookup <hostname>.et.net 100.100.100.101'),
      );
    });
  });

  test('zone helpers strip the trailing dot', () {
    expect(magicDnsZoneBase('et.net.'), 'et.net');
    expect(magicDnsZoneBase('corp'), 'corp');
    expect(magicDnsNameOf(host: 'laptop', zone: 'et.net.'), 'laptop.et.net');
  });
}

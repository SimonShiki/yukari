import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/privilege.dart';
import 'package:yukari/system/magic_dns.dart';

import '../fake_system_command.dart';

void main() {
  group('Linux probe', () {
    test('a configured link reports configured and its interface', () async {
      final command = FakeSystemCommand(
        runHandler: linuxHost(configured: () => true),
      );

      final probe = await linuxSystem(command)
          .probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.configured);
      expect(probe.interface, 'et_12_xoih');
      expect(command.elevated, isEmpty);
    });

    test('an unconfigured link reports missing', () async {
      final command = FakeSystemCommand(runHandler: linuxHost());

      final probe = await linuxSystem(command)
          .probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.missing);
      expect(probe.interface, 'et_12_xoih');
    });

    test('a configured TUN name is used when the route is not there', () async {
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) {
          if (executable == 'ip' && arguments.first == '-4') {
            return ok('');
          }
          if (executable == 'ip' && arguments.first == 'link') {
            return ok('');
          }
          return linuxHost()(executable, arguments);
        },
      );

      final probe = await linuxSystem(command)
          .probe(zone: 'et.net.', interfaceName: 'mytun');

      expect(probe.state, MagicDnsState.missing);
      expect(probe.interface, 'mytun');
    });

    test('a missing interface reports noInterface', () async {
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) {
          if (executable == 'ip' && arguments.first == '-4') {
            return ok('');
          }
          return failed();
        },
      );

      final probe = await linuxSystem(command)
          .probe(zone: 'et.net.', interfaceName: 'gone');

      expect(probe.state, MagicDnsState.noInterface);
      expect(probe.interface, isNull);
    });

    test('a host without resolvectl reports unsupported', () async {
      final command = FakeSystemCommand(
        runHandler: linuxHost(resolvectl: false),
      );

      final probe = await linuxSystem(command)
          .probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.unsupported);
      expect(probe.interface, 'et_12_xoih');
    });
  });

  group('Linux apply and reset', () {
    test('apply authors one elevated shell command for both steps', () async {
      final command = FakeSystemCommand();

      await linuxSystem(command)
          .apply(zone: 'et.net.', interfaceName: 'et_12_xoih');

      expect(command.runs, isEmpty);
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

    test('apply rejects a zone or interface unsafe for a shell', () async {
      final command = FakeSystemCommand();
      final system = linuxSystem(command);

      await expectLater(
        system.apply(zone: 'et.net; touch /tmp/pwned', interfaceName: 'eth0'),
        throwsArgumentError,
      );
      await expectLater(
        system.apply(zone: 'et.net.', interfaceName: "eth0'; touch /tmp/x; '"),
        throwsArgumentError,
      );
      expect(command.elevated, isEmpty);
    });

    test('a dismissed elevation surfaces the failure', () async {
      final command = FakeSystemCommand(
        elevateHandler: (_, _) async =>
            throw const ElevationException('Authorization was dismissed'),
      );

      await expectLater(
        linuxSystem(command)
            .apply(zone: 'et.net.', interfaceName: 'et_12_xoih'),
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

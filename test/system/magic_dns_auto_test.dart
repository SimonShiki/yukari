import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns_auto.dart';

import '../fake_system_command.dart';

Network _network({
  bool acceptDns = true,
  bool noTun = false,
  String zone = 'et.net.',
  String deviceName = '',
  String? ipv4 = '10.126.126.2/24',
}) => Network()
  ..networkName = 'alpha'
  ..ipv4 = ipv4
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun
    ..dnsZone = zone
    ..deviceName = deviceName);

MagicDnsAuto _auto(FakeSystemCommand command, {int attempts = 5}) =>
    MagicDnsAuto(
      system: androidSystem(command),
      attempts: attempts,
      retryDelay: Duration.zero,
    );

void main() {
  test('skips a network whose DNS is already configured', () async {
    final command = FakeSystemCommand(
      runHandler: androidHost(configured: () => true, jump: () => true),
    );

    final interface = await _auto(command).start('n1', _network());

    expect(interface, isNull);
    expect(command.elevated, isEmpty);
  });

  test('applies the DNS when the interface is there', () async {
    final command = FakeSystemCommand(runHandler: androidHost());

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(command.runs.any((run) => run.$1 == 'iptables'), isTrue);
  });

  test('names no TUN and no address, so nothing is applied', () async {
    final command = FakeSystemCommand(runHandler: androidHost());

    final interface = await _auto(
      command,
      attempts: 2,
    ).start('n1', _network(ipv4: ''));

    expect(interface, isNull);
    expect(command.runs, isEmpty, reason: 'nothing may be guessed');
    expect(command.elevated, isEmpty);
  });

  test('applies the address EasyTier assigned to a DHCP network', () async {
    var reads = 0;
    final command = FakeSystemCommand(runHandler: androidHost());
    final auto = MagicDnsAuto(
      system: androidSystem(command),
      attempts: 5,
      retryDelay: Duration.zero,
      // The instance reports the address it was assigned only after a retry.
      assignedAddress: (_) async => reads++ < 2 ? null : '10.126.126.2/24',
    );

    final interface = await auto.start('n1', _network(ipv4: null));

    expect(interface, 'et_12_xoih');
    expect(reads, 3, reason: 'read again on every attempt');
    expect(command.runs.any((run) => run.$1 == 'iptables'), isTrue);
  });

  test('an assigned address that never comes keeps failing closed', () async {
    final command = FakeSystemCommand(runHandler: androidHost());
    final auto = MagicDnsAuto(
      system: androidSystem(command),
      attempts: 2,
      retryDelay: Duration.zero,
      assignedAddress: (_) async => null,
    );

    final interface = await auto.start('n1', _network(ipv4: null));

    expect(interface, isNull);
    expect(command.runs, isEmpty, reason: 'nothing may be guessed');
    expect(command.elevated, isEmpty);
  });

  test(
    'the saved address is the fallback when the provider has none',
    () async {
      final command = FakeSystemCommand(runHandler: androidHost());
      final auto = MagicDnsAuto(
        system: androidSystem(command),
        attempts: 2,
        retryDelay: Duration.zero,
        assignedAddress: (_) async => null,
      );

      final interface = await auto.start('n1', _network());

      expect(interface, 'et_12_xoih');
      expect(command.runs.any((run) => run.$1 == 'iptables'), isTrue);
    },
  );

  test('waits for an interface that is still being created', () async {
    var missing = 2;
    final command = FakeSystemCommand(
      // The first address lookups find nothing; the TUN appears afterwards.
      runHandler: (executable, arguments) {
        if (executable == 'ip' && arguments.contains('addr') && missing > 0) {
          missing--;
          return ok('');
        }
        return androidHost()(executable, arguments);
      },
    );

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(missing, 0, reason: 'the probe retried until the TUN appeared');
    expect(command.runs.any((run) => run.$1 == 'iptables'), isTrue);
  });

  test('gives up after the bounded attempts, without configuring', () async {
    final command = FakeSystemCommand(runHandler: (_, _) => ok(''));

    final interface = await _auto(command, attempts: 3).start('n1', _network());

    expect(interface, isNull);
    expect(command.runs, hasLength(3));
    expect(command.elevated, isEmpty);
  });

  test('never touches a network it does not apply to', () async {
    final command = FakeSystemCommand(runHandler: androidHost());
    final auto = _auto(command);

    expect(auto.appliesTo(_network(acceptDns: false)), isFalse);
    expect(auto.appliesTo(_network(noTun: true)), isFalse);
    expect(auto.appliesTo(_network()), isTrue);
    expect(await auto.start('n1', _network(acceptDns: false)), isNull);
    expect(await auto.start('n2', _network(noTun: true)), isNull);
    expect(await auto.start('n3', _network()), isNotNull);
    expect(command.runs, isNotEmpty, reason: 'the applicable one probed');
  });

  test('Windows and Linux hosts need nothing from MagicDnsAuto', () async {
    final command = FakeSystemCommand();

    for (final system in [windowsSystem(command), linuxSystem(command)]) {
      expect(MagicDnsAuto(system: system).appliesTo(_network()), isFalse);
      expect(
        await MagicDnsAuto(system: system).start('n1', _network()),
        isNull,
      );
    }
    expect(command.runs, isEmpty);
    expect(command.elevated, isEmpty);
  });

  test('a failed setup never reaches the caller', () async {
    final command = FakeSystemCommand(
      runHandler: (_, _) => throw StateError('boom'),
    );

    expect(await _auto(command).start('n1', _network()), isNull);
  });

  test('reverts only what it configured, and forgets it', () async {
    final command = FakeSystemCommand(runHandler: androidHost());
    final auto = _auto(command);
    await auto.start('n1', _network());
    await auto.start('n2', _network(zone: 'corp.internal'));

    int deleteCalls() => command.runs
        .where((run) => run.$1 == 'iptables' && run.$2.contains('-D'))
        .length;

    final before = deleteCalls();
    // A network whose DNS was not configured is not owned.
    await auto.revert('n3');
    expect(deleteCalls(), before);

    await auto.revert('n1');
    final afterFirst = deleteCalls();
    expect(afterFirst, greaterThan(before));
    await auto.revert('n1');
    expect(deleteCalls(), afterFirst, reason: 'reverted once');

    await auto.revertAll();
    expect(deleteCalls(), greaterThan(afterFirst), reason: 'only n2 was left');
  });

  test('reverts a configuration it inherited', () async {
    final command = FakeSystemCommand(
      runHandler: androidHost(configured: () => true, jump: () => true),
    );
    final auto = _auto(command);

    // A killed service left the rule installed: the probe finds it, and the
    // network still owns it once it runs here.
    expect(await auto.start('n1', _network()), isNull);
    final runsBefore = command.runs.length;

    await auto.revert('n1');

    expect(
      command.runs.skip(runsBefore).any((run) => run.$2.contains('-D')),
      isTrue,
    );
  });

  test('a second start configures nothing again', () async {
    var configured = false;
    final command = FakeSystemCommand(
      runHandler: (executable, arguments) {
        if (executable == 'iptables' && arguments.contains('-A')) {
          configured = true;
        }
        return androidHost(
          configured: () => configured,
          jump: () => configured,
        )(executable, arguments);
      },
    );
    final auto = _auto(command);
    final network = _network();

    expect(await auto.start('n1', network), 'et_12_xoih');
    final runsAfterFirst = command.runs.length;
    expect(
      await auto.start('n1', network),
      isNull,
      reason: 'the second probe finds the configuration in place',
    );
    expect(
      command.runs.skip(runsAfterFirst).any((run) => run.$2.contains('-A')),
      isFalse,
      reason: 'applied once, not twice',
    );

    await auto.revert('n1');
    expect(
      command.runs.any((run) => run.$1 == 'iptables' && run.$2.contains('-D')),
      isTrue,
    );
  });
}

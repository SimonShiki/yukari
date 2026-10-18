import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/privilege.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/system/magic_dns_auto.dart';

import '../fake_system_command.dart';

Network _network({
  bool acceptDns = true,
  bool noTun = false,
  String zone = 'et.net.',
  String deviceName = '',
}) => Network()
  ..networkName = 'alpha'
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun
    ..dnsZone = zone
    ..deviceName = deviceName);

MagicDnsAuto _auto(FakeSystemCommand command, {int attempts = 5}) =>
    MagicDnsAuto(
      system: linuxSystem(command),
      attempts: attempts,
      retryDelay: Duration.zero,
    );

void main() {
  test('skips a network whose DNS is already configured', () async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => true),
    );

    final interface = await _auto(command).start('n1', _network());

    expect(interface, isNull);
    expect(command.elevated, isEmpty);
  });

  test('applies the DNS when the interface is there', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(command.elevated.single.$1, 'sh');
    expect(
      command.elevated.single.$2.last,
      allOf(
        contains("resolvectl dns 'et_12_xoih' 100.100.100.101"),
        contains("resolvectl domain 'et_12_xoih' '~et.net'"),
      ),
    );
  });

  test('waits for an interface that is still being created', () async {
    var routes = 0;
    final command = FakeSystemCommand(
      // The first route lookups find nothing; the interface appears afterwards.
      runHandler: (executable, arguments) {
        if (executable == 'ip' && arguments.first == '-4') {
          routes++;
          return routes < 3
              ? ok('')
              : ok('100.100.100.101 dev et_12_xoih src 10.126.126.2 uid 1000');
        }
        return linuxHost()(executable, arguments);
      },
    );

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(routes, 3);
    expect(command.elevated, hasLength(1));
  });

  test('gives up after the bounded attempts, without elevating', () async {
    final command = FakeSystemCommand(runHandler: (_, _) => ok(''));

    final interface = await _auto(command, attempts: 3).start('n1', _network());

    expect(interface, isNull);
    expect(command.runs, hasLength(3));
    expect(command.elevated, isEmpty);
  });

  test('never touches a network it does not apply to', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    final auto = _auto(command);

    expect(auto.appliesTo(_network(acceptDns: false)), isFalse);
    expect(auto.appliesTo(_network(noTun: true)), isFalse);
    expect(auto.appliesTo(_network()), isTrue);
    expect(await auto.start('n1', _network(acceptDns: false)), isNull);
    expect(await auto.start('n2', _network(noTun: true)), isNull);
    expect(await auto.start('n3', _network()), isNotNull);
    expect(command.runs, isNotEmpty, reason: 'the applicable one probed');
  });

  test('a Windows host needs nothing', () async {
    final command = FakeSystemCommand();

    expect(
      MagicDnsAuto(system: windowsSystem(command)).appliesTo(_network()),
      isFalse,
    );
    expect(
      await MagicDnsAuto(system: windowsSystem(command))
          .start('n1', _network()),
      isNull,
    );
    expect(command.runs, isEmpty);
  });

  test('a failed elevation never reaches the caller', () async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(),
      elevateHandler: (_, _) async =>
          throw const ElevationException('Authorization was dismissed'),
    );

    expect(await _auto(command).start('n1', _network()), isNull);
  });

  test('reverts only what it configured, and forgets it', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    final auto = _auto(command);
    await auto.start('n1', _network());
    await auto.start('n2', _network());
    expect(command.elevated, hasLength(2));

    // A network whose DNS was already configured is not owned.
    await auto.revert('n3');
    expect(command.elevated, hasLength(2));

    await auto.revert('n1');
    expect(command.elevated.last.$1, 'resolvectl');
    expect(command.elevated.last.$2, ['revert', 'et_12_xoih']);
    await auto.revert('n1');
    expect(command.elevated, hasLength(3), reason: 'reverted once');

    await auto.revertAll();
    expect(command.elevated, hasLength(4), reason: 'only n2 was left');
  });
}

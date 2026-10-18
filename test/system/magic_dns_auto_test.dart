import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/backend/privilege.dart';
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

  test("another VPN's TUN keeps its DNS", () async {
    final command = FakeSystemCommand(runHandler: linuxHost());

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(command.elevated.single.$2.last, contains("'et_12_xoih'"));
    expect(command.elevated.single.$2.last, isNot(contains('FlClash')));
  });

  test('names no TUN and no address, so nothing is applied', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());

    final interface = await _auto(command, attempts: 2)
        .start('n1', _network(ipv4: ''));

    expect(interface, isNull);
    expect(command.runs, isEmpty, reason: 'nothing may be guessed');
    expect(command.elevated, isEmpty);
  });

  test('applies the address EasyTier assigned to a DHCP network', () async {
    var reads = 0;
    final command = FakeSystemCommand(runHandler: linuxHost());
    final auto = MagicDnsAuto(
      system: linuxSystem(command),
      attempts: 5,
      retryDelay: Duration.zero,
      // The instance reports the address it was assigned only after a retry.
      assignedAddress: (_) async =>
          reads++ < 2 ? null : '10.126.126.2/24',
    );

    final interface = await auto.start('n1', _network(ipv4: null));

    expect(interface, 'et_12_xoih');
    expect(reads, 3, reason: 'read again on every attempt');
    expect(
      command.elevated.single.$2.last,
      contains("resolvectl dns 'et_12_xoih' 100.100.100.101"),
    );
  });

  test('an assigned address that never comes keeps failing closed', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    final auto = MagicDnsAuto(
      system: linuxSystem(command),
      attempts: 2,
      retryDelay: Duration.zero,
      assignedAddress: (_) async => null,
    );

    final interface = await auto.start('n1', _network(ipv4: null));

    expect(interface, isNull);
    expect(command.runs, isEmpty, reason: 'nothing may be guessed');
    expect(command.elevated, isEmpty);
  });

  test('the saved address is the fallback when the provider has none', () async {
    final command = FakeSystemCommand(runHandler: linuxHost());
    final auto = MagicDnsAuto(
      system: linuxSystem(command),
      attempts: 2,
      retryDelay: Duration.zero,
      assignedAddress: (_) async => null,
    );

    final interface = await auto.start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(command.elevated, hasLength(1));
  });

  test('waits for an interface that is still being created', () async {
    var missing = 2;
    final command = FakeSystemCommand(
      // The first address lookups find nothing; the TUN appears afterwards.
      runHandler: (executable, arguments) {
        if (executable == 'ip' && arguments.contains('addr') && missing > 0) {
          missing--;
          return ok('');
        }
        return linuxHost()(executable, arguments);
      },
    );

    final interface = await _auto(command).start('n1', _network());

    expect(interface, 'et_12_xoih');
    expect(missing, 0, reason: 'the probe retried until the TUN appeared');
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

  test('reverts a configuration it inherited', () async {
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => true),
    );
    final auto = _auto(command);

    // A killed service left the link configured: the probe finds it, and the
    // network still owns it once it runs here.
    expect(await auto.start('n1', _network()), isNull);
    expect(command.elevated, isEmpty, reason: 'nothing had to be installed');

    await auto.revert('n1');

    expect(command.elevated.single.$1, 'resolvectl');
    expect(command.elevated.single.$2, ['revert', 'et_12_xoih']);
  });

  test('a second start configures nothing again', () async {
    var configured = false;
    final command = FakeSystemCommand(
      runHandler: linuxHost(configured: () => configured),
      elevateHandler: (_, _) async => configured = true,
    );
    final auto = _auto(command);
    final network = _network();

    expect(await auto.start('n1', network), 'et_12_xoih');
    expect(
      await auto.start('n1', network),
      isNull,
      reason: 'the second probe finds the configuration in place',
    );

    expect(command.elevated, hasLength(1), reason: 'applied once, not twice');

    await auto.revert('n1');
    expect(command.elevated.last.$2, ['revert', 'et_12_xoih']);
  });
}

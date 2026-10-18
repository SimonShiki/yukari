import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';
import 'package:yukari_core/system/magic_dns_auto.dart';
import 'package:yukari_core/system/system_command.dart';

import '../fake_system_command.dart';

/// The zone lookup, as `iptables` receives it.
const _rule = [
  '-t',
  'nat',
  '-A',
  'YUKARI_MAGIC_DNS',
  '-p',
  'udp',
  '--dport',
  '53',
  '-m',
  'string',
  '--algo',
  'bm',
  '--hex-string',
  '|02|et|03|net|00|',
  '-j',
  'DNAT',
  '--to-destination',
  '100.100.100.101:53',
];

/// The same rule as the kernel prints it, for the chain fake.
const _zoneRule =
    '-p udp --dport 53 -m string --algo bm --hex-string '
    '|02|et|03|net|00| -j DNAT --to-destination 100.100.100.101:53';

Network _network({
  bool acceptDns = true,
  bool noTun = false,
  String zone = 'et.net.',
}) => Network()
  ..networkName = 'alpha'
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun
    ..dnsZone = zone);

/// The verbs of [command]'s iptables calls, in order.
List<String> _verbs(FakeSystemCommand command) => [
  for (final (executable, arguments) in command.runs)
    if (executable == 'iptables') arguments[2],
];

/// [command]'s iptables calls, in order.
List<(String, List<String>)> _iptables(FakeSystemCommand command) => [
  for (final run in command.runs)
    if (run.$1 == 'iptables') run,
];

/// The bytes an `iptables -m string` hex-string spells.
List<int> _patternBytes(String pattern) => [
  for (final part in pattern.split('|'))
    if (part.isEmpty)
      ...const <int>[]
    else if (RegExp(r'^[0-9a-f]{2}$').hasMatch(part))
      int.parse(part, radix: 16)
    else
      ...part.codeUnits,
];

MagicDnsAuto _auto(FakeSystemCommand command) => MagicDnsAuto(
  system: androidSystem(command),
  attempts: 2,
  retryDelay: Duration.zero,
);

/// An Android host whose chain holds the rules in [rules], as the kernel
/// would: adding keeps one, deleting forgets it, `-S` prints what is there,
/// and the jump from OUTPUT exists when [jumped] says so.
CommandResult? Function(String, List<String>) _chainHost(
  List<String> rules, {
  String resolvConf = '',
  bool jumped = false,
}) => (executable, arguments) {
  if (executable == 'cat') return ok(resolvConf);
  if (executable == 'ip' && arguments.first == '-4') {
    return ok('100.100.100.101 dev et_12_xoih src 10.126.126.2 uid 0');
  }
  if (executable != 'iptables') return null;
  if (arguments.contains('--help')) return ok('');
  final target = arguments[3];
  final rule = target == 'OUTPUT'
      ? ''
      : arguments.sublist(4).skip(arguments[2] == '-I' ? 1 : 0).join(' ');
  switch (arguments[2]) {
    case '-A':
      rules.add(rule);
    case '-I':
      if (target == 'OUTPUT') {
        jumped = true;
      } else {
        rules.insert(0, rule);
      }
    case '-D':
      if (target == 'OUTPUT') {
        jumped = false;
      } else if (!rules.remove(rule)) {
        return failed();
      }
    case '-F':
      rules.clear();
    case '-C':
      if (target == 'OUTPUT') return jumped ? ok('') : failed();
      return rules.contains(rule) ? ok('') : failed();
    case '-S':
      return ok(
        '-N YUKARI_MAGIC_DNS\n'
        '${[for (final line in rules) '-A YUKARI_MAGIC_DNS $line\n'].join()}',
      );
  }
  return ok('');
};

void main() {
  group('the zone pattern', () {
    test('spells the zone as the wire bytes of its labels', () {
      expect(magicDnsZoneHex('et.net.'), '|02|et|03|net|00|');
      expect(magicDnsZoneHex('corp.internal'), '|04|corp|08|internal|00|');
    });

    test('refuses a zone that is not a plain DNS name', () {
      expect(magicDnsZoneHex(''), isNull);
      expect(magicDnsZoneHex('et..net'), isNull);
      expect(magicDnsZoneHex('et net'), isNull);
      expect(magicDnsZoneHex('et.net; reboot'), isNull);
      expect(magicDnsZoneHex('-et.net'), isNull);
      expect(magicDnsZoneHex('${'a' * 64}.net'), isNull);
    });

    test('matches the zone labels only, never a name that contains them', () {
      // The same bytes the helper spells, as a resolver puts them on the wire.
      expect(
        _patternBytes(magicDnsZoneHex('et.net.')!),
        '\x02et\x03net\x00'.codeUnits,
      );
      const zone = '\x02et\x03net\x00';
      const wire = {
        'laptop.et.net': '\x06laptop\x02et\x03net\x00',
        'et.net': '\x02et\x03net\x00',
        'a.b.et.net': '\x01a\x01b\x02et\x03net\x00',
        'x.et.net.evil.com': '\x01x\x02et\x03net\x04evil\x03com\x00',
        'bet.net': '\x03bet\x03net\x00',
        'myet.net': '\x04myet\x03net\x00',
        'et.netfoo.com': '\x02et\x06netfoo\x03com\x00',
      };
      for (final MapEntry(:key, :value) in wire.entries) {
        expect(
          value.contains(zone),
          key.endsWith('.et.net') || key == 'et.net',
          reason: key,
        );
      }
    });
  });

  group('the Android probe', () {
    test('reports configured when the rule and the jump are there', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(configured: () => true, jump: () => true),
      );

      final probe = await androidSystem(
        command,
      ).probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.configured);
      expect(probe.interface, 'et_12_xoih');
      expect(command.elevated, isEmpty);
    });

    test('reports missing when the rule is not installed', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(jump: () => true),
      );

      final probe = await androidSystem(
        command,
      ).probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.missing);
      expect(probe.interface, 'et_12_xoih');
    });

    test('reports missing when the jump from OUTPUT is gone', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(configured: () => true),
      );

      final probe = await androidSystem(
        command,
      ).probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.missing);
    });

    test('waits while the tunnel has no route yet', () async {
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) =>
            executable == 'ip' ? ok('') : androidHost()(executable, arguments),
      );

      final probe = await androidSystem(
        command,
      ).probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.noInterface);
      expect(probe.interface, isNull);
    });

    test('reports unsupported without iptables', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(iptables: false),
      );

      final probe = await androidSystem(
        command,
      ).probe(zone: 'et.net.', interfaceName: '');

      expect(probe.state, MagicDnsState.unsupported);
      expect(probe.interface, 'et_12_xoih');
    });

    test('an unusable zone runs nothing and is unsupported', () async {
      final command = FakeSystemCommand(runHandler: androidHost());

      final probe = await androidSystem(
        command,
      ).probe(zone: 'bad zone', interfaceName: '');
      await androidSystem(command).apply(zone: 'bad zone', interfaceName: '');

      expect(probe.state, MagicDnsState.unsupported);
      expect(probe.interface, isNull);
      expect(command.runs, isEmpty);
    });

    test('offers no hand-written fallback', () {
      final command = FakeSystemCommand();

      expect(
        androidSystem(
          command,
        ).manualCommands(zone: 'et.net.', interfaceName: ''),
        isEmpty,
      );
      expect(command.runs, isEmpty);
    });
  });

  group('the Android redirect', () {
    test('returns EasyTier\'s upstreams, then redirects the zone', () async {
      final command = FakeSystemCommand(runHandler: androidHost());

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      expect(_verbs(command), [
        '--help',
        '-N',
        '-C',
        '-I',
        '-C',
        '-I',
        '-D',
        '-A',
        '-D',
        '-I',
      ]);
      final calls = _iptables(command);
      expect(calls[3].$2, [
        '-t',
        'nat',
        '-I',
        'YUKARI_MAGIC_DNS',
        '1',
        '-p',
        'udp',
        '--dport',
        '53',
        '-d',
        '223.5.5.5/32',
        '-j',
        'RETURN',
      ]);
      expect(calls[5].$2, contains('180.184.1.1/32'));
      expect(calls[7].$2, _rule);
      expect(calls[9].$2, [
        '-t',
        'nat',
        '-I',
        'OUTPUT',
        '1',
        '-j',
        'YUKARI_MAGIC_DNS',
      ]);
      expect(command.elevated, isEmpty, reason: 'the service is already root');
    });

    test('returns the name servers the resolver file names', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(
          resolvConf:
              'nameserver 192.168.1.1\n'
              'nameserver 2001:db8::1\n'
              '# nameserver 9.9.9.9\n',
        ),
      );

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      final returned = [
        for (final (_, arguments) in _iptables(command))
          if (arguments[2] == '-I' &&
              arguments[3] == 'YUKARI_MAGIC_DNS' &&
              arguments.contains('-d'))
            arguments[arguments.indexOf('-d') + 1],
      ];
      expect(returned, contains('192.168.1.1/32'));
      expect(returned, isNot(contains('2001:db8::1/32')));
      expect(
        returned,
        hasLength(3),
        reason: 'the fallback pair and the one IPv4 name server',
      );
    });

    test('re-applying replaces the rule, with one jump at the front', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));
      final system = androidSystem(command);

      await system.apply(zone: 'et.net.', interfaceName: '');
      await system.apply(zone: 'et.net.', interfaceName: '');

      expect(
        rules.where((rule) => rule.contains('--hex-string')),
        hasLength(1),
        reason: 'one rule per zone',
      );
      expect(
        rules.where((rule) => rule.contains('-j RETURN')),
        hasLength(2),
        reason: 'the upstream rules are not duplicated',
      );
    });

    test('two zones share the chain', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));
      final system = androidSystem(command);

      await system.apply(zone: 'et.net.', interfaceName: '');
      await system.apply(zone: 'corp.internal', interfaceName: '');

      final zoneRules = rules
          .where((rule) => rule.contains('--hex-string'))
          .toList();
      expect(zoneRules, hasLength(2));
      expect(zoneRules[0], contains('|02|et|03|net|00|'));
      expect(zoneRules[1], contains('|04|corp|08|internal|00|'));
      expect(
        _verbs(command),
        isNot(contains('-F')),
        reason: 'another zone\'s rule is never flushed',
      );
      final probe = await system.probe(zone: 'et.net.', interfaceName: '');
      expect(probe.state, MagicDnsState.configured);
    });

    test('a zone rule never matches an app lookup for another name', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      final lookup = rules.firstWhere((rule) => rule.contains('--hex-string'));
      expect(lookup, contains('--hex-string |02|et|03|net|00|'));
      expect(
        lookup,
        isNot(contains('--uid-owner')),
        reason: 'netd resolves for every app, so uids cannot tell them apart',
      );
      expect(
        rules.where((rule) => rule.contains('-j RETURN')).length,
        2,
        reason: 'EasyTier\'s forwarder upstreams are returned, not redirected',
      );
    });

    test('an unusable match leaves the tables alone', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(matches: false),
      );

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      expect(_verbs(command), ['--help']);
      expect(command.runs.single.$2, ['-m', 'string', '--help']);
    });

    test('without iptables the first check is all that runs', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(iptables: false),
      );

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      expect(command.runs, hasLength(1));
    });

    test('a failed install leaves no chain behind', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(
        runHandler: (executable, arguments) {
          if (executable == 'iptables' && arguments[2] == '-A') return failed();
          return _chainHost(rules)(executable, arguments);
        },
      );

      await androidSystem(command).apply(zone: 'et.net.', interfaceName: '');

      expect(rules, isEmpty);
      expect(_verbs(command).last, '-X');
    });

    test('reset removes the last rule, then the jump and chain', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(
        runHandler: _chainHost(rules, jumped: true),
      );
      final system = androidSystem(command);
      await system.apply(zone: 'et.net.', interfaceName: '');

      await system.reset(zone: 'et.net.', interfaceName: 'et_12_xoih');

      expect(rules, isEmpty);
      expect(_verbs(command).sublist(_verbs(command).length - 5), [
        '-D',
        '-S',
        '-D',
        '-F',
        '-X',
      ]);
      expect(command.elevated, isEmpty);
    });

    test('reset keeps a sibling zone\'s rule and the chain', () async {
      final rules = <String>[
        _zoneRule,
        _zoneRule.replaceAll('|02|et|03|net|00|', '|04|corp|08|internal|00|'),
      ];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));

      await androidSystem(
        command,
      ).reset(zone: 'corp.internal', interfaceName: 'et_12_xoih');

      expect(rules, [_zoneRule]);
      expect(_verbs(command), ['-D', '-S']);
    });

    test('reset for a zone that was never applied changes nothing', () async {
      final rules = <String>[_zoneRule];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));

      await androidSystem(
        command,
      ).reset(zone: 'corp.internal', interfaceName: 'et_12_xoih');

      expect(rules, [_zoneRule]);
      expect(_verbs(command), ['-D', '-S']);
    });

    test('reset without a zone touches nothing at all', () async {
      final command = FakeSystemCommand(runHandler: androidHost());

      await androidSystem(command).reset(interfaceName: 'et_12_xoih');

      expect(command.runs, isEmpty);
    });
  });

  group('the service flow', () {
    test('a Magic DNS network installs the redirect and reverts it', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));
      final auto = _auto(command);

      final interface = await auto.start('n1', _network());

      expect(interface, 'et_12_xoih');
      expect(rules, contains(_zoneRule));

      await auto.revert('n1');

      expect(rules, isEmpty);
    });

    test('a redirect the service inherited is reverted too', () async {
      // A previous service was killed with its rule installed: the probe finds
      // it, and the network still owns it.
      final rules = <String>[_zoneRule];
      final command = FakeSystemCommand(
        runHandler: _chainHost(rules, jumped: true),
      );
      final auto = _auto(command);

      expect(
        await auto.start('n1', _network()),
        isNull,
        reason: 'nothing had to be installed',
      );

      await auto.revert('n1');

      expect(rules, isEmpty);
    });

    test('two running networks keep their own zones', () async {
      final rules = <String>[];
      final command = FakeSystemCommand(runHandler: _chainHost(rules));
      final auto = _auto(command);

      await auto.start('n1', _network());
      await auto.start('n2', _network(zone: 'corp.internal'));
      await auto.revert('n1');

      final zoneRules = rules
          .where((rule) => rule.contains('--hex-string'))
          .toList();
      expect(zoneRules, hasLength(1), reason: 'the sibling zone survives');
      expect(zoneRules.single, contains('|04|corp|08|internal|00|'));
      expect(_verbs(command), isNot(contains('-X')));
    });

    test('a network that does not ask for Magic DNS touches nothing', () async {
      final command = FakeSystemCommand(runHandler: androidHost());
      final auto = _auto(command);

      expect(auto.appliesTo(_network(acceptDns: false)), isFalse);
      expect(auto.appliesTo(_network(noTun: true)), isFalse);
      expect(await auto.start('n1', _network(acceptDns: false)), isNull);
      expect(await auto.start('n2', _network(noTun: true)), isNull);

      expect(command.runs, isEmpty);
    });

    test('a host without iptables never fails a start', () async {
      final command = FakeSystemCommand(
        runHandler: androidHost(iptables: false),
      );

      expect(await _auto(command).start('n1', _network()), isNull);
      expect(command.elevated, isEmpty);
    });
  });
}

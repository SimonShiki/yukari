part of 'magic_dns.dart';

/// The nat chain the Android service owns.
const _androidChain = 'YUKARI_MAGIC_DNS';

/// The name servers EasyTier's forwarder falls back to when it cannot read a
/// system resolver configuration (`common/dns.rs`).
const _forwarderFallbacks = ['223.5.5.5', '180.184.1.1'];

/// One `nameserver` line of a resolv.conf.
final _nameServer = RegExp(r'^\s*nameserver\s+(\d{1,3}(?:\.\d{1,3}){3})\b');

/// The lookup a network's zone needs: a UDP DNS query for a name in the zone,
/// whichever server it was sent to.
List<String> _lookupRule(String pattern) => [
  '-p',
  'udp',
  '--dport',
  '53',
  '-m',
  'string',
  '--algo',
  'bm',
  '--hex-string',
  pattern,
  '-j',
  'DNAT',
  '--to-destination',
  '$magicDnsServer:53',
];

/// The rule that keeps a query EasyTier forwarded from being sent back into
/// the tunnel.
///
/// A zone query aimed at such a server is deliberately left alone: it keeps
/// whatever Android's own resolver answers, which is the fail-safe side of the
/// redirect and never a loop.
List<String> _returnRule(String server) => [
  '-p',
  'udp',
  '--dport',
  '53',
  '-d',
  '$server/32',
  '-j',
  'RETURN',
];

/// The servers EasyTier's forwarder can query: its built-in fallback, and the
/// ones the system resolver file names.
///
/// Read again on every apply, so the set covers both branches that forwarder
/// chooses between: the system resolver file when it can read one, else the
/// built-in fallback pair.
Future<Set<String>> _forwarderUpstreams(MagicDnsSystem system) async {
  final upstreams = <String>{..._forwarderFallbacks};
  final conf = await system._try('cat', ['/etc/resolv.conf']);
  for (final line in (conf?.stdout ?? '').split('\n')) {
    final server = _nameServer.firstMatch(line)?.group(1);
    if (server != null) upstreams.add(server);
  }
  return upstreams;
}

/// Puts the [upstreams] above the zone rules, once each.
Future<void> _ensureUpstreams(
  MagicDnsSystem system,
  Set<String> upstreams,
) async {
  for (final server in upstreams) {
    final rule = _returnRule(server);
    final present = await system._try('iptables', [
      '-t',
      'nat',
      '-C',
      _androidChain,
      ...rule,
    ]);
    if (present == null || present.exitCode == 0) continue;
    await system._try('iptables', [
      '-t',
      'nat',
      '-I',
      _androidChain,
      '1',
      ...rule,
    ]);
  }
}

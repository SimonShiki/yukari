part of 'magic_dns.dart';

/// Android's side of Magic DNS for the root service.
///
/// Android has no API that points its resolver at a single zone, so the
/// service sends the zone's own lookups into the EasyTier tunnel: the chain
/// matches UDP DNS queries whose name ends in the zone, and everything else
/// keeps using Android's own resolver.
///
/// It cannot tell whose query it sees: netd resolves for every app over the
/// `dnsproxyd` socket, so an app's lookup carries root's socket credentials
/// just like EasyTier's own. Loop safety therefore comes from the
/// destination: every server EasyTier's forwarder can query is returned above
/// the zone rules, so a zone name it forwards upstream can never come back
/// into the tunnel.
extension MagicDnsAndroid on MagicDnsSystem {
  /// Whether the service's redirect is installed for [zone], and the EasyTier
  /// interface its route points at.
  ///
  /// The redirect sends the lookup into the tunnel, so the tunnel's route has
  /// to be there first: an interface that is still coming up is waited for.
  /// The rule alone is not the redirect either: nothing reaches the chain
  /// without the jump from OUTPUT.
  Future<MagicDnsProbe> _probeAndroid({
    required String zone,
    required String interfaceName,
  }) async {
    final pattern = magicDnsZoneHex(zone);
    if (pattern == null) {
      return (state: MagicDnsState.unsupported, interface: null);
    }
    final interface = await _findInterface(interfaceName);
    if (interface == null) {
      return (state: MagicDnsState.noInterface, interface: null);
    }
    final installed = await _try('iptables', [
      '-t',
      'nat',
      '-C',
      _androidChain,
      ..._lookupRule(pattern),
    ]);
    if (installed == null) {
      return (state: MagicDnsState.unsupported, interface: interface);
    }
    if (installed.exitCode != 0) {
      return (state: MagicDnsState.missing, interface: interface);
    }
    final jumped = await _try('iptables', [
      '-t',
      'nat',
      '-C',
      'OUTPUT',
      '-j',
      _androidChain,
    ]);
    if (jumped == null) {
      return (state: MagicDnsState.unsupported, interface: interface);
    }
    return (
      state: jumped.exitCode == 0
          ? MagicDnsState.configured
          : MagicDnsState.missing,
      interface: interface,
    );
  }

  /// Installs the redirect for [zone], leaving every other zone's rule alone.
  ///
  /// This zone's rule is deleted before it is added, so re-applying keeps one,
  /// and the jump is moved to the front, so no other module's blanket DNS
  /// redirect can swallow the zone's lookups before this chain sees them.
  ///
  /// A rule a killed service left behind is not this zone's to drop: it only
  /// ever matches names of a zone nobody runs, and the probe is what lets its
  /// own network revert it once that network starts again.
  Future<void> _applyAndroid({required String zone}) async {
    final pattern = magicDnsZoneHex(zone);
    if (pattern == null) return;
    // A host whose iptables cannot match strings cannot serve the zone.
    final canMatch = await _try('iptables', ['-m', 'string', '--help']);
    if (canMatch == null || canMatch.exitCode != 0) return;
    if (await _try('iptables', ['-t', 'nat', '-N', _androidChain]) == null) {
      return;
    }
    await _ensureUpstreams(this, await _forwarderUpstreams(this));
    final rule = _lookupRule(pattern);
    await _try('iptables', ['-t', 'nat', '-D', _androidChain, ...rule]);
    final added = await _try('iptables', [
      '-t',
      'nat',
      '-A',
      _androidChain,
      ...rule,
    ]);
    if (added == null || added.exitCode != 0) {
      // No rule was added: a chain with no zone left has nothing to serve.
      await _dropChainIfUnused();
      return;
    }
    const jump = ['-t', 'nat', '-I', 'OUTPUT', '1', '-j', _androidChain];
    await _try('iptables', ['-t', 'nat', '-D', 'OUTPUT', '-j', _androidChain]);
    await _try('iptables', jump);
  }

  /// Removes [zone]'s rule, and the chain with its jump once no zone is left.
  ///
  /// A zone that was never applied removes nothing but its own rule, which is
  /// not there.
  Future<void> _resetAndroid({String? zone}) async {
    final pattern = zone == null ? null : magicDnsZoneHex(zone);
    if (pattern == null) return;
    await _try('iptables', [
      '-t',
      'nat',
      '-D',
      _androidChain,
      ..._lookupRule(pattern),
    ]);
    await _dropChainIfUnused();
  }

  /// Drops the chain, its upstream rules and its jump when no zone rule is
  /// left to reach them.
  Future<void> _dropChainIfUnused() async {
    final rules = await _try('iptables', ['-t', 'nat', '-S', _androidChain]);
    if (rules == null || rules.exitCode != 0) return;
    if (rules.stdout.contains('-j DNAT')) return;
    await _try('iptables', ['-t', 'nat', '-D', 'OUTPUT', '-j', _androidChain]);
    await _try('iptables', ['-t', 'nat', '-F', _androidChain]);
    await _try('iptables', ['-t', 'nat', '-X', _androidChain]);
  }
}

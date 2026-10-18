part of 'network_editor_magic_dns.dart';

/// The Magic DNS helper's actions: the probe, the manual apply and reset, and
/// the quiet retry that follows a state needing attention.
extension MagicDnsActions on MagicDnsController {
  /// The configuration Magic DNS is serving: the running instance's, when
  /// there is one, else the saved network's.
  Network? get _currentNetwork =>
      running.instances.peek()[networkId]?.network ??
      saved.networks.peek()[networkId];

  /// Checks the system DNS again.
  Future<void> refresh() async {
    if (_disposed || busy.peek()) return;
    final network = _currentNetwork;
    if (network == null) return;
    await _guard(() => _probe(network));
  }

  /// Configures the EasyTier interface's DNS, then reports the new state.
  Future<void> apply() async {
    if (_disposed || busy.peek()) return;
    final network = _currentNetwork;
    if (network == null) return;
    await _guard(() async {
      var name = interfaceName.peek();
      if (name.isEmpty) {
        final probe = await system.probe(
          zone: network.flags.dnsZone,
          interfaceName: network.flags.deviceName,
        );
        _report(probe);
        name = interfaceName.peek();
        if (name.isEmpty) return;
      }
      await system.apply(zone: network.flags.dnsZone, interfaceName: name);
      await _probe(network);
    });
  }

  /// Clears a partial configuration after a failed attempt.
  Future<void> reset() async {
    if (_disposed || busy.peek()) return;
    final network = _currentNetwork;
    final name = interfaceName.peek();
    if (network == null || name.isEmpty) return;
    await _guard(() async {
      await system.reset(interfaceName: name);
      await _probe(network);
    });
  }

  /// Re-probes without the busy state, so a late automatic setup hides the
  /// card without the spinner.
  Future<void> _recheck() async {
    final network = _currentNetwork;
    if (network == null) return;
    try {
      final probe = await system.probe(
        zone: network.flags.dnsZone,
        interfaceName: network.flags.deviceName,
      );
      if (_disposed) return;
      _report(probe);
    } catch (_) {
      // A read-only retry; the manual recheck reports problems instead.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    busy.value = true;
    error.value = null;
    try {
      await action();
    } catch (failure) {
      if (_disposed) return;
      error.value = '$failure';
      _set(MagicDnsState.failed);
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  Future<void> _probe(Network network) async {
    final probe = await system.probe(
      zone: network.flags.dnsZone,
      interfaceName: network.flags.deviceName,
    );
    if (_disposed) return;
    _report(probe);
  }

  void _report(MagicDnsProbe probe) {
    if (probe.interface case final found?) interfaceName.value = found;
    _set(probe.state);
  }

  void _set(MagicDnsState next) {
    if (state.peek() != next) state.value = next;
  }
}

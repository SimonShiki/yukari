import 'dart:async';

import '../models/models.dart';
import 'magic_dns.dart';

/// Configures the system DNS for Magic DNS automatically.
///
/// Injected into the background service, so the daemon can be tested without
/// touching the host's resolver.
abstract interface class MagicDnsSetup {
  /// Whether [network] should get system DNS from this setup at all.
  bool appliesTo(Network network);

  /// Configures system DNS for the network that started as [networkId].
  ///
  /// Returns the EasyTier interface it configured, or null when the DNS was
  /// already in place or could not be set up.
  Future<String?> start(String networkId, Network network);

  /// Reverts the DNS [start] configured for [networkId], if this setup still
  /// owns it; a no-op otherwise.
  Future<void> revert(String networkId);

  /// Reverts every interface this setup configured, such as when the service
  /// stops.
  Future<void> revertAll();
}

/// Sets the system DNS up once per network start.
///
/// A start probes first: an interface whose DNS is already correct is left
/// alone, and an interface that is still being created is waited for a bounded
/// number of times. Every failure is swallowed, so a network's start never
/// depends on this.
final class MagicDnsAuto implements MagicDnsSetup {
  MagicDnsAuto({
    MagicDnsSystem? system,
    this.attempts = 40,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : system = system ?? MagicDnsSystem();

  final MagicDnsSystem system;

  /// How often a start waits for the EasyTier interface to appear.
  final int attempts;

  /// How long each of those waits is.
  final Duration retryDelay;

  /// The interfaces this setup configured, by network id.
  final _configured = <String, String>{};

  @override
  bool appliesTo(Network network) =>
      system.configurable && network.flags.acceptDns && !network.flags.noTun;

  @override
  Future<String?> start(String networkId, Network network) async {
    if (!appliesTo(network)) return null;
    final zone = network.flags.dnsZone;
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final probe = await system.probe(
          zone: zone,
          interfaceName: network.flags.deviceName,
        );
        switch (probe.state) {
          case MagicDnsState.configured:
          case MagicDnsState.unsupported:
          case MagicDnsState.off:
          case MagicDnsState.notRunning:
          case MagicDnsState.failed:
            return null;
          case MagicDnsState.missing:
            final interface = probe.interface;
            if (interface == null) return null;
            await system.apply(zone: zone, interfaceName: interface);
            _configured[networkId] = interface;
            return interface;
          case MagicDnsState.noInterface:
            // The network just started: its TUN device and the route to the
            // Magic DNS server may still be coming up.
            if (attempt + 1 < attempts) {
              await Future<void>.delayed(retryDelay);
            }
        }
      }
    } catch (_) {
      // Best-effort: the card still offers the manual fallback.
    }
    return null;
  }

  @override
  Future<void> revert(String networkId) async {
    final interface = _configured.remove(networkId);
    if (interface == null) return;
    try {
      await system.reset(interfaceName: interface);
    } catch (_) {
      // Nothing is left to revert, such as after the interface is gone.
    }
  }

  @override
  Future<void> revertAll() async {
    for (final id in _configured.keys.toList()) {
      await revert(id);
    }
  }
}

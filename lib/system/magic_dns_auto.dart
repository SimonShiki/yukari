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

  /// The configurations this setup installed, by network id: the EasyTier
  /// interface and the zone each was installed for.
  final _configured = <String, ({String interface, String zone})>{};

  @override
  bool appliesTo(Network network) =>
      system.configurable && magicDnsRequested(network.flags);

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
            // Nothing was installed here, but the configuration is this
            // network's: remembering it is what lets a redirect a killed
            // service left behind be reverted when its network stops.
            if (probe.interface case final interface?) {
              _configured[networkId] = (interface: interface, zone: zone);
            }
            return null;
          case MagicDnsState.unsupported:
          case MagicDnsState.off:
          case MagicDnsState.notRunning:
          case MagicDnsState.failed:
            return null;
          case MagicDnsState.missing:
            final interface = probe.interface;
            if (interface == null) return null;
            await system.apply(zone: zone, interfaceName: interface);
            _configured[networkId] = (interface: interface, zone: zone);
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
    final configured = _configured.remove(networkId);
    if (configured == null) return;
    try {
      await system.reset(
        interfaceName: configured.interface,
        zone: configured.zone,
      );
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

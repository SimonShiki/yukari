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
    this.assignedAddress,
  }) : system = system ?? MagicDnsSystem();

  final MagicDnsSystem system;

  /// How often a start waits for the EasyTier interface to appear.
  final int attempts;

  /// How long each of those waits is.
  final Duration retryDelay;

  /// The virtual IPv4 EasyTier assigned to the instance running [networkId].
  ///
  /// A network configured for DHCP has no address of its own until its
  /// instance reports one, so this is read again on every attempt. Null reads
  /// the saved network only.
  final Future<String?> Function(String networkId)? assignedAddress;

  /// The configurations this setup installed, by network id: the EasyTier
  /// interface and the zones each was installed for.
  final _configured = <String, ({String interface, List<String> zones})>{};

  @override
  bool appliesTo(Network network) =>
      system.supported && magicDnsRequested(network.flags);

  @override
  Future<String?> start(String networkId, Network network) async {
    if (!appliesTo(network)) return null;
    final zones = network.magicDnsZones;
    if (zones.isEmpty) return null;
    final primaryZone = zones.first;
    final deviceName = network.flags.deviceName;
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final address = await assignedAddress?.call(networkId) ?? network.ipv4;
        final probe = await system.probe(
          zone: primaryZone,
          interfaceName: deviceName,
          address: address,
        );
        switch (probe.state) {
          case MagicDnsState.configured:
            // Nothing was installed for the primary zone, but any extra
            // static zones still need their redirects; remembering them all
            // lets revert() clean them up when this network stops.
            if (probe.interface case final interface?) {
              final installed = <String>[primaryZone];
              for (final extra in zones.skip(1)) {
                final extraProbe = await system.probe(
                  zone: extra,
                  interfaceName: deviceName,
                  address: address,
                );
                if (extraProbe.state == MagicDnsState.missing) {
                  await system.apply(
                    zone: extra,
                    interfaceName: deviceName,
                    address: address,
                  );
                  installed.add(extra);
                } else if (extraProbe.state == MagicDnsState.configured) {
                  installed.add(extra);
                }
              }
              _configured[networkId] = (interface: interface, zones: installed);
            }
            return null;
          case MagicDnsState.unsupported:
            return null;
          case MagicDnsState.missing:
            // The interface the probe resolved is the one apply configures:
            // both read the same hints through the same helper.
            final interface = probe.interface;
            if (interface == null) return null;
            final installed = <String>[];
            for (final zone in zones) {
              final currentProbe = zone == primaryZone
                  ? probe
                  : await system.probe(
                      zone: zone,
                      interfaceName: deviceName,
                      address: address,
                    );
              if (currentProbe.state == MagicDnsState.missing) {
                await system.apply(
                  zone: zone,
                  interfaceName: deviceName,
                  address: address,
                );
                installed.add(zone);
              } else if (currentProbe.state == MagicDnsState.configured) {
                installed.add(zone);
              }
            }
            if (installed.isNotEmpty) {
              _configured[networkId] = (interface: interface, zones: installed);
            }
            return interface;
          case MagicDnsState.noInterface:
            // The network just started: its TUN device and the address it
            // owns may still be coming up.
            if (attempt + 1 < attempts) {
              await Future<void>.delayed(retryDelay);
            }
        }
      }
    } catch (_) {
      // Best-effort: a network's start never depends on system DNS.
    }
    return null;
  }

  @override
  Future<void> revert(String networkId) async {
    final configured = _configured.remove(networkId);
    if (configured == null) return;
    try {
      for (final zone in configured.zones) {
        await system.reset(
          interfaceName: configured.interface,
          zone: zone,
        );
      }
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

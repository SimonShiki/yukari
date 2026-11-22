import 'dart:async';

import 'package:signals/signals.dart';

import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';

import '../signals/instances.dart' as running;
import '../signals/magic_dns.dart';
import '../signals/networks.dart' as saved;

import 'signal_scope.dart';

part 'network_editor_magic_dns_actions.dart';

/// One network's Magic DNS helper: whether it shows, what the system DNS is
/// doing, and the actions that check or change it.
///
/// The network editor shows it where Magic DNS is enabled, and a running
/// network's peers tab shows it where the system DNS can actually be
/// configured. Both read the saved network and running-instance stores, so a
/// page creates one and disposes of it. The actions live in
/// `network_editor_magic_dns_actions.dart`.
class MagicDnsController with SignalScope {
  MagicDnsController({required this.networkId, MagicDnsSystem? system})
    : system = system ?? MagicDnsSystem() {
    addCleanup(
      effect(() {
        if (!enabled.value) {
          _set(MagicDnsState.off);
          restoreMagicDnsCard(networkId);
          return;
        }
        if (instance.value == null) {
          _set(MagicDnsState.notRunning);
          _probed = false;
          restoreMagicDnsCard(networkId);
          return;
        }
        running.instancesRevision.value;
        // A collection runs every few seconds. The first one after the network
        // started probes the system; later ones retry a problem state quietly,
        // so the automatic setup finishing late still hides the card.
        if (!_probed) {
          _probed = true;
          unawaited(refresh());
          return;
        }
        // Only states waiting for the interface settle by themselves; a failed
        // attempt keeps its error (and its cleanup action) until the user acts.
        final current = state.peek();
        if ((current == MagicDnsState.noInterface ||
                current == MagicDnsState.missing) &&
            !busy.peek()) {
          unawaited(_recheck());
        }
      }),
    );
    addCleanup(
      effect(() {
        final current = state.value;
        if (!this.system.supported ||
            current == MagicDnsState.off ||
            current == MagicDnsState.configured ||
            current == MagicDnsState.notRunning ||
            dismissed.value) {
          return;
        }
        _settle ??= Timer(const Duration(milliseconds: 1200), () {
          _settled.value = true;
        });
      }),
    );
  }

  /// The saved network whose Magic DNS this controller explains.
  final String networkId;

  /// The platform side, which the card also reads to choose its wording.
  final MagicDnsSystem system;

  late final ReadonlySignal<Network?> network = derive(
    () => saved.networks.value[networkId],
  );

  late final ReadonlySignal<Instance?> instance = derive(
    () => running.instances.value[networkId],
  );

  /// Whether this network asks for Magic DNS at all.
  late final ReadonlySignal<bool> enabled = derive(() {
    final flags = network.value?.flags;
    return flags != null && magicDnsRequested(flags);
  });

  /// The network's virtual IPv4: the address EasyTier assigned to the running
  /// instance, else the saved one. Null when neither knows one, which is what
  /// makes the probe fail closed rather than guess an interface.
  late final ReadonlySignal<String?> address = derive(
    () => instance.value?.myself?.virtualIpv4 ?? network.value?.ipv4,
  );

  /// The zone names this network's peers live under, such as `et.net.`.
  late final ReadonlySignal<String> zone = derive(
    () =>
        instance.value?.network.flags.dnsZone ??
        network.value?.flags.dnsZone ??
        magicDnsDefaultZone,
  );

  /// This device's Magic DNS name: the running instance's hostname when it is
  /// up, else the configured one; null when neither names this device.
  late final ReadonlySignal<String?> magicName = derive(() {
    final runningHost = instance.value?.myself?.hostname ?? '';
    final configuredHost = network.value?.hostname ?? '';
    final host = runningHost.isNotEmpty ? runningHost : configuredHost;
    if (host.isEmpty) return null;
    return magicDnsNameOf(host: host, zone: zone.value);
  });

  /// The state the card shows.
  late final Signal<MagicDnsState> state = own(MagicDnsState.off);

  /// Whether a probe or an elevated command is running.
  late final Signal<bool> busy = own(false);

  /// Why the last probe or command failed, when [MagicDnsState.failed].
  late final Signal<String?> error = own(null);

  /// The EasyTier interface the probe found, empty until it finds one.
  late final Signal<String> interfaceName = own('');

  /// Whether the user closed this network's card for the session.
  late final ReadonlySignal<bool> dismissed = derive(
    () => magicDnsDismissedCards.value.contains(networkId),
  );

  late final _settled = own(false);
  Timer? _settle;

  // Give automatic setup time to finish before showing a problem.
  late final showCard = derive(() {
    final current = state.value;
    return system.supported &&
        !dismissed.value &&
        current != MagicDnsState.off &&
        current != MagicDnsState.configured &&
        (current == MagicDnsState.notRunning || _settled.value);
  });

  /// Hides the card until the network stops.
  void dismiss() => dismissMagicDnsCard(networkId);

  bool _probed = false;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _settle?.cancel();
    disposeSignals();
  }
}

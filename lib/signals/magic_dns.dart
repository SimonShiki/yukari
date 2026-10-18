import 'dart:async';

import 'package:signals/signals.dart';

import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns_auto.dart';
import 'backend.dart' as backends;
import 'instances.dart' as running;

/// The network ids whose Magic DNS card the user closed this session.
final Signal<Set<String>> _dismissedCards = signal(const {});

/// The closed Magic DNS cards, for the card's controller to follow.
ReadonlySignal<Set<String>> get magicDnsDismissedCards => _dismissedCards;

/// Hides this network's Magic DNS card until the network stops.
///
/// Both helpers peek at the store: they run from effects and actions that must
/// not subscribe to it.
void dismissMagicDnsCard(String networkId) {
  final cards = _dismissedCards.peek();
  if (cards.contains(networkId)) return;
  _dismissedCards.value = {...cards, networkId};
}

/// Shows this network's Magic DNS card again, such as after it stopped.
void restoreMagicDnsCard(String networkId) {
  final cards = _dismissedCards.peek();
  if (!cards.contains(networkId)) return;
  _dismissedCards.value = {...cards}..remove(networkId);
}

/// Clears the session's closed cards, as each test's setup does.
void resetMagicDnsDismissedCards() => _dismissedCards.value = const {};

/// The app-mode side of automatic Magic DNS: watches the running instances
/// store and configures the system DNS for every network that starts here.
///
/// The background service configures its own instances (see `ServiceDaemon`),
/// so this effect stands down while the service backend is active.
final class AppMagicDnsAuto {
  AppMagicDnsAuto({
    MagicDnsSetup? setup,
    ReadonlySignal<BackendKind>? backendKind,
  }) : setup = setup ?? MagicDnsAuto(),
       backendKind = backendKind ?? backends.backendKind {
    _stop = effect(_sync);
  }

  final MagicDnsSetup setup;

  /// Where the networks run; injected so tests can switch modes.
  final ReadonlySignal<BackendKind> backendKind;

  final _started = <String>{};
  final _running = <String>{};
  late final void Function() _stop;

  void dispose() {
    _stop();
    _started.clear();
    _running.clear();
  }

  void _sync() {
    final instances = running.instances.value;
    final runningIds = instances.keys.toSet();
    // Whatever ran this effect, a network that left the running store offers
    // its closed card again. This is independent of whether this effect was
    // the one configuring that network (service mode, Windows, no-Tun).
    for (final id in _running.difference(runningIds)) {
      restoreMagicDnsCard(id);
    }
    _running
      ..clear()
      ..addAll(runningIds);
    _started.removeWhere((id) => !runningIds.contains(id));

    // The service daemon sets the DNS up for the instances it runs.
    if (backendKind.value == BackendKind.service) {
      _started.clear();
      return;
    }
    for (final MapEntry(:key, :value) in instances.entries) {
      if (value.status != InstanceStatus.running) continue;
      if (_started.contains(key)) continue;
      if (!setup.appliesTo(value.network)) continue;
      _started.add(key);
      unawaited(_start(key, value.network));
    }
  }

  /// One attempt per start; the setup itself is best-effort and never throws.
  Future<void> _start(String networkId, Network network) async {
    try {
      await setup.start(networkId, network);
    } catch (_) {
      // A failed setup must never affect the running network.
    }
  }
}

AppMagicDnsAuto? _auto;

/// Starts app-mode automatic Magic DNS; call once, after [initBackend].
///
/// The setup reads the address EasyTier assigned to the running instance, so a
/// network configured for DHCP can be resolved to its own TUN.
AppMagicDnsAuto initMagicDnsAuto() {
  _auto?.dispose();
  return _auto = AppMagicDnsAuto(
    setup: MagicDnsAuto(
      assignedAddress: (id) async =>
          running.instances.peek()[id]?.myself?.virtualIpv4,
    ),
  );
}

import 'package:flutter/foundation.dart';
import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/instance.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/peer.dart';

import 'instance_logs.dart';
import 'networks.dart' as saved;

/// Global running-instance state: the one place the home dashboard, the
/// networks list and the instance pages read what is running.
///
/// The app relies on the initial empty state and never resets this store;
/// [initInstances] is the tests' reset, so one test cannot see the instances
/// another collected.
///
/// [refreshInstances] is the only writer of a collected map, so concurrent
/// refreshes of one backend coalesce into a single call, and [forgetInstances]
/// drops ids a delete or stop made stale. Read [instances], keyed by network
/// id, and [instancesLoaded].
final Signal<Map<String, Instance>> _instances = signal({});
final Signal<bool> _loaded = signal(false);
final Signal<int> _revision = signal(0);
Map<String, Network>? _collectedNetworks;

/// The running instances, keyed by network id, as of the last collection.
ReadonlySignal<Map<String, Instance>> get instances => _instances;

/// Whether the backend answered at least once.
ReadonlySignal<bool> get instancesLoaded => _loaded;

/// Successful collection sequence, for consumers that recheck external state
/// even when the instance data is unchanged.
ReadonlySignal<int> get instancesRevision => _revision;

/// The collection every caller of [_refreshingBackend] shares while it runs.
Future<Map<String, Instance>>? _inFlight;
NetworkBackend? _refreshingBackend;

/// Bumped by [initInstances], so a collection that outlives a reset cannot
/// write its stale answer into the fresh store.
int _generation = 0;

/// Collects every running instance once for every concurrent caller of the
/// same [backend], records the reported events, and answers what the backend
/// reported. Throws when the backend cannot answer, leaving the last known
/// state in place and releasing the in-flight guard, so callers keep their own
/// policy: the dashboard swallows it and shows the backend's status, the list
/// reports it.
///
/// Callers of a different backend collect on their own, so one backend's slow
/// answer never blocks another's.
Future<Map<String, Instance>> refreshInstances(NetworkBackend backend) {
  final inFlight = _inFlight;
  if (inFlight != null && identical(_refreshingBackend, backend)) {
    return inFlight;
  }
  final started = _collect(backend, _generation);
  _inFlight = started;
  _refreshingBackend = backend;
  return started.whenComplete(() {
    if (identical(_inFlight, started)) {
      _inFlight = null;
      _refreshingBackend = null;
    }
  });
}

Future<Map<String, Instance>> _collect(
  NetworkBackend backend,
  int generation,
) async {
  final networks = saved.networks.peek();
  final collected = await backend.collect(networks);
  // A collection that outlives a reset belongs to the store's previous life;
  // it records nothing and writes nothing.
  if (generation != _generation) return collected;
  for (final MapEntry(:key, :value) in collected.entries) {
    recordInstanceEvents(key, value.events);
  }
  batch(() {
    _publishInstances(collected, networks);
    _loaded.value = true;
    _revision.value = _revision.peek() + 1;
  });
  return collected;
}

/// Forgets [ids], such as after they are deleted or stopped, without waiting
/// for the next collection.
void forgetInstances(Iterable<String> ids) {
  final forgotten = ids.toSet();
  if (!forgotten.any(_instances.peek().containsKey)) return;
  _instances.value = Map.unmodifiable({
    for (final MapEntry(:key, :value) in _instances.peek().entries)
      if (!forgotten.contains(key)) key: value,
  });
}

/// Empties the store, as each test's setup does, so one test cannot see the
/// instances another collected.
void initInstances() {
  _generation++;
  _inFlight = null;
  _refreshingBackend = null;
  _collectedNetworks = null;
  batch(() {
    if (_instances.peek().isNotEmpty) _instances.value = const {};
    _loaded.value = false;
    _revision.value = 0;
  });
}

void _publishInstances(
  Map<String, Instance> collected,
  Map<String, Network> networks,
) {
  final current = _instances.peek();
  // A saved map may contain in-place edits to existing mutable networks.
  final sameNetworks = identical(networks, _collectedNetworks);
  _collectedNetworks = networks;
  final next = <String, Instance>{};
  for (final MapEntry(:key, :value) in collected.entries) {
    final previous = current[key];
    next[key] =
        sameNetworks && previous != null && _sameInstance(previous, value)
        ? previous
        : value;
  }
  // Order matters to consumers that show the first running network's data.
  if (mapEquals(current, next) &&
      listEquals(current.keys.toList(), next.keys.toList())) {
    return;
  }
  _instances.value = Map.unmodifiable(next);
}

bool _sameInstance(Instance a, Instance b) =>
    identical(a, b) ||
    (identical(a.network, b.network) &&
        a.status == b.status &&
        a.version == b.version &&
        listEquals(a.events, b.events) &&
        _samePeer(a.myself, b.myself) &&
        a.peers.length == b.peers.length &&
        a.peers.indexed.every(
          (entry) => _samePeer(entry.$2, b.peers[entry.$1]),
        ));

bool _samePeer(Peer? a, Peer? b) =>
    identical(a, b) ||
    (a != null &&
        b != null &&
        a.id == b.id &&
        a.identityType == b.identityType &&
        a.hostname == b.hostname &&
        a.latency == b.latency &&
        a.rxBytes == b.rxBytes &&
        a.txBytes == b.txBytes &&
        a.rxPackets == b.rxPackets &&
        a.txPackets == b.txPackets &&
        a.secureAuthLevel == b.secureAuthLevel &&
        listEquals(a.protocols, b.protocols) &&
        a.natType == b.natType &&
        a.connectionType == b.connectionType &&
        a.virtualIpv4 == b.virtualIpv4);

import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';
import 'package:yukari_core/models/instance.dart';
import 'instance_logs.dart';
import 'networks.dart' as saved;

/// Global running-instance state: the one place the home dashboard, the
/// networks list and the instance pages read what is running.
///
/// **Initialization**: the app relies on the initial empty state and never
/// resets this store; [initInstances] is the tests' reset, so one test cannot
/// see the instances another collected.
///
/// **Mutation**: [refreshInstances] is the only writer of a collected map, so
/// concurrent refreshes of one backend coalesce into a single call, and
/// [forgetInstances] drops ids a delete or stop made stale.
///
/// **Read**: [instances], keyed by network id, and [instancesLoaded].
final Signal<Map<String, Instance>> _instances = signal({});
final Signal<bool> _loaded = signal(false);

/// The running instances, keyed by network id, as of the last collection.
ReadonlySignal<Map<String, Instance>> get instances => _instances;

/// Whether the backend answered at least once.
ReadonlySignal<bool> get instancesLoaded => _loaded;

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
  final collected = await backend.collect(saved.networks.peek());
  // A collection that outlives a reset belongs to the store's previous life;
  // it records nothing and writes nothing.
  if (generation != _generation) return collected;
  for (final MapEntry(:key, :value) in collected.entries) {
    recordInstanceEvents(key, value.events);
  }
  batch(() {
    _instances.value = Map.unmodifiable(collected);
    _loaded.value = true;
  });
  return collected;
}

/// Forgets [ids], such as after they are deleted or stopped, without waiting
/// for the next collection.
void forgetInstances(Iterable<String> ids) {
  final forgotten = ids.toSet();
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
  batch(() {
    _instances.value = const {};
    _loaded.value = false;
  });
}

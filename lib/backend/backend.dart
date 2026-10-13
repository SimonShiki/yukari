import 'dart:convert';

import 'package:signals/signals.dart';

import '../models/models.dart';

/// Runs EasyTier network instances for the app.
///
/// The app talks to every backend the same way: in process through FFI
/// (`FfiBackend`, `AndroidBackend`), or through the privileged background
/// service (`ServiceBackend`). The service itself serves an `FfiBackend`, so
/// both sides share one contract. Instances are named after their network.
abstract class NetworkBackend {
  BackendKind get kind;

  /// Whether the backend can currently take requests.
  ReadonlySignal<BackendStatus> get status;

  /// How many instances may run at once, or null when unlimited.
  int? get maxInstances => null;

  /// Raw EasyTier information of the running instances, keyed by name.
  Future<Map<String, String>> collectInfos();

  /// Starts the saved network [id], completing once the instance is up.
  ///
  /// Throws when EasyTier rejects the network. Later failures show in the
  /// information [collectInfos] reports.
  Future<void> start(String id, Network network);

  /// Stops the instances named [names].
  Future<void> stop(List<String> names);

  /// Whether [network] may create its TUN device, asking the user if needed.
  Future<TunAccess> tunAccess(Network network);

  /// Whether [elevate] can grant missing privileges on this platform.
  bool get canElevate => false;

  /// Relaunches the app with the privileges TUN devices need.
  ///
  /// Returns true when an elevated instance was launched, which then takes
  /// over from this one.
  Future<bool> elevate() async => false;

  /// The running instances among [networks], keyed by network id.
  Future<Map<String, Instance>> collect(Map<String, Network> networks) async =>
      hydrateInstances(networks, await collectInfos());

  /// Releases the backend. In-process backends stop their instances.
  Future<void> dispose();
}

/// Matches EasyTier [infos], keyed by instance name, to saved [networks].
Map<String, Instance> hydrateInstances(
  Map<String, Network> networks,
  Map<String, String> infos,
) => {
  for (final MapEntry(:key, :value) in networks.entries)
    if (infos[value.networkName] case final info?)
      key: Instance.fromJsonAndNetwork(
        jsonDecode(info) as Map<String, Object?>,
        value,
      ),
};

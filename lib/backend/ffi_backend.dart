import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:signals/signals.dart';

import '../bindings/easytier_ffi_native.dart' as native;
import '../models/models.dart';
import '../utils/easytier_config_serializer.dart';
import 'backend.dart';
import 'privilege.dart';

/// Runs instances inside this process through the EasyTier FFI library.
///
/// The app uses it directly, and the background service serves it to the
/// app over IPC. FFI calls run on helper isolates.
class FfiBackend extends NetworkBackend {
  /// Serializes list-style calls, as each frees the previous call's result.
  Future<void> _listing = Future.value();
  bool _disposed = false;

  @override
  BackendKind get kind => BackendKind.ffi;

  @override
  final ReadonlySignal<BackendStatus> status = signal(BackendStatus.ready);

  @override
  Future<Map<String, String>> collectInfos() =>
      _list(native.collectNetworkInfos);

  /// EasyTier starts the instance in the background and returns, or throws
  /// when it rejects the configuration or the name is taken.
  @override
  Future<void> start(String id, Network network) {
    if (_disposed) return Future.error(StateError('Backend disposed'));
    return _run(_instanceConfig(network));
  }

  @override
  Future<void> stop(List<String> names) => _delete(names);

  @override
  Future<TunAccess> tunAccess(Network network) async =>
      network.flags.noTun || canCreateTun()
      ? TunAccess.granted
      : TunAccess.elevationRequired;

  @override
  bool get canElevate => Platform.isWindows;

  @override
  Future<bool> elevate() => relaunchElevated();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop((await _list(native.listInstances)).keys.toList());
  }

  Future<Map<String, String>> _list(Map<String, String> Function() read) {
    final result = _listing.then((_) => Isolate.run(read));
    _listing = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// The instance's TOML; naming it after the network lets collect and stop
/// address it without a persisted id.
String _instanceConfig(Network network) =>
    'instance_name = ${jsonEncode(network.networkName)}\n'
    '${network.toEasyTierToml()}';

// Isolate entry points stay top-level so they capture nothing unsendable.

Future<void> _run(String config) =>
    Isolate.run(() => native.runNetworkInstance(config));

Future<void> _delete(List<String> names) => names.isEmpty
    ? Future.value()
    : Isolate.run(() => native.deleteNetworkInstances(names));

import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:signals/signals.dart';

import '../models/models.dart';
import 'backend.dart';
import 'ipc/ipc_client.dart';
import 'ipc/ipc_endpoint.dart';

/// Thrown when the background service cannot be reached.
final class ServiceUnavailableException implements Exception {
  const ServiceUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'The Yukari service is unavailable: $cause';
}

/// Runs instances in the privileged background service, reached over IPC.
///
/// The service reads networks from the shared store itself, so starting one
/// sends only its id. The connection is opened once and kept: while it is there
/// every request reuses it, and nothing reaches out on its own.
///
/// A service that restarts publishes the port and token it listens on again, so
/// the connection the app holds is gone. The next request then opens a new one
/// from what the service published, and only [retry] asks for a check before
/// that. [status] reports the answer the last attempt gave rather than
/// announcing each attempt, so a service that is down does not make the pages
/// that show it flicker.
class ServiceBackend extends NetworkBackend {
  ServiceBackend(this._locate) {
    _connect().ignore();
  }

  /// Finds the running service; see [IpcEndpoint.locate].
  final Future<IpcEndpoint> Function() _locate;

  final _status = signal(BackendStatus.connecting);
  Client? _client;
  Future<Client>? _connecting;
  bool _disposed = false;

  @override
  BackendKind get kind => BackendKind.service;

  @override
  ReadonlySignal<BackendStatus> get status => _status;

  @override
  Future<void> retry() async {
    if (_disposed) return;
    try {
      await _connect();
    } catch (_) {
      // The check reported its answer through [status].
    }
  }

  @override
  Future<Map<String, String>> collectInfos() async =>
      (await _request('collect') as Map<String, Object?>).cast();

  @override
  Future<void> start(String id, Network network) =>
      _request('start', {'id': id});

  @override
  Future<void> stop(List<String> names) => _request('stop', {'names': names});

  /// The service runs privileged, so every network may create its TUN.
  @override
  Future<TunAccess> tunAccess(Network network) async => TunAccess.granted;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _status.dispose();
    await _client?.close();
  }

  Future<Object?> _request(String method, [Object? params]) async =>
      (await _connect()).sendRequest(method, params);

  Future<Client> _connect() {
    if (_disposed) return Future.error(StateError('Backend disposed'));
    if (_client case final client? when !client.isClosed) {
      return Future.value(client);
    }
    return _connecting ??= _open().whenComplete(() => _connecting = null);
  }

  Future<Client> _open() async {
    final Client client;
    try {
      client = await connectIpc(await _locate());
    } catch (error) {
      // The backend may have been disposed while locating the service, and
      // its status signal was disposed with it.
      if (!_disposed) _status.value = BackendStatus.unavailable;
      throw ServiceUnavailableException(error);
    }
    if (_disposed) {
      await client.close();
      throw StateError('Backend disposed');
    }
    client.done.whenComplete(() {
      if (!_disposed && identical(_client, client)) {
        _status.value = BackendStatus.unavailable;
      }
    }).ignore();
    _status.value = BackendStatus.ready;
    return _client = client;
  }
}

import 'dart:async';

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
/// sends only its id. While the service is unreachable, such as when an
/// update restarts it, tries again every [retryInterval] until it answers.
class ServiceBackend extends NetworkBackend {
  ServiceBackend(
    this._locate, {
    this.retryInterval = const Duration(seconds: 2),
  }) {
    _connect().ignore();
  }

  /// Finds the running service; see [IpcEndpoint.locate].
  final Future<IpcEndpoint> Function() _locate;
  final Duration retryInterval;

  final _status = signal(BackendStatus.connecting);
  Client? _client;
  Future<Client>? _connecting;
  Timer? _retry;
  bool _disposed = false;

  @override
  BackendKind get kind => BackendKind.service;

  @override
  ReadonlySignal<BackendStatus> get status => _status;

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
    _retry?.cancel();
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
    if (_status.peek() != BackendStatus.ready) {
      _status.value = BackendStatus.connecting;
    }
    final Client client;
    try {
      client = await connectIpc(await _locate());
    } catch (error) {
      // The backend may have been disposed while locating the service, and
      // its status signal was disposed with it.
      if (!_disposed) {
        _status.value = BackendStatus.unavailable;
        _retryLater();
      }
      throw ServiceUnavailableException(error);
    }
    if (_disposed) {
      await client.close();
      throw StateError('Backend disposed');
    }
    client.done.whenComplete(() {
      if (!_disposed && identical(_client, client)) {
        _status.value = BackendStatus.unavailable;
        _retryLater();
      }
    }).ignore();
    _status.value = BackendStatus.ready;
    return _client = client;
  }

  void _retryLater() {
    if (_disposed || _retry != null) return;
    _retry = Timer(retryInterval, () {
      _retry = null;
      _connect().ignore();
    });
  }
}

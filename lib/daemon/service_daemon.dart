import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart';

import '../backend/backend.dart';
import '../backend/ipc/ipc_server.dart';
import '../models/models.dart';
import '../storage/network_store.dart';

/// The background service: serves [backend] to the app over IPC and starts
/// the networks marked [Network.autoStart] when it comes up.
///
/// Networks are read from [store], which the app owns; the service never
/// writes it and only starts networks saved there.
final class ServiceDaemon {
  ServiceDaemon({required this.store, required this.backend, this.log = _log})
    : assert(store.readOnly, 'The service must not write the network store');

  final NetworkStore store;
  final NetworkBackend backend;
  final void Function(String message) log;
  IpcServer? _server;

  /// Serves the app on [socket], admitting peers that present [token], then
  /// starts the networks marked to start on boot.
  Future<void> start(ServerSocket socket, {String? token}) async {
    _server = IpcServer(socket, methods: _methods, token: token);
    log('Serving on ${socket.address.address}');
    await _autoStart();
  }

  /// Stops serving and stops every instance.
  Future<void> stop() async {
    await _server?.close();
    await backend.dispose();
    log('Stopped');
  }

  Future<void> _autoStart() async {
    final Map<String, Network> saved;
    try {
      saved = await store.load();
    } catch (error) {
      log('Could not read ${store.file.path}: $error');
      return;
    }
    for (final MapEntry(:key, :value) in saved.entries) {
      if (!value.autoStart) continue;
      try {
        await backend.start(key, value);
        log('Started ${value.networkName}');
      } catch (error) {
        log('Could not start ${value.networkName}: $error');
      }
    }
  }

  Map<String, IpcMethod> get _methods => {
    'collect': (_) => backend.collectInfos(),
    'start': (params) => _start(params['id'].asString),
    'stop': (params) => backend.stop([
      for (final name in params['names'].asList)
        if (name is String)
          name
        else
          throw RpcException.invalidParams('Instance names must be strings'),
    ]),
  };

  Future<void> _start(String id) async {
    // Read afresh: the app saves edits right before starting a network.
    final network = (await store.load())[id];
    if (network == null) {
      throw RpcException.invalidParams('Network $id is not saved');
    }
    await backend.start(id, network);
    log('Started ${network.networkName}');
  }
}

void _log(String message) => stderr.writeln(message);

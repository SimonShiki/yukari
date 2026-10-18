import 'dart:async';
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart';

import '../backend/backend.dart';
import '../backend/ipc/ipc_server.dart';
import '../backend/service_version.dart';
import '../models/models.dart';
import '../storage/network_store.dart';
import '../system/magic_dns_auto.dart';

/// The background service: serves [backend] to the app over IPC and starts
/// the networks marked [Network.autoStart] when it comes up.
///
/// It also configures the system DNS for the Magic DNS networks it runs: this
/// process has the privileges Linux needs, so the app never has to prompt for
/// them. Networks are read from [store], which the app owns; the service never
/// writes it and only starts networks saved there.
final class ServiceDaemon {
  ServiceDaemon({
    required this.store,
    required this.backend,
    MagicDnsSetup? magicDns,
    this.log = _log,
  }) : assert(store.readOnly, 'The service must not write the network store') {
    this.magicDns = magicDns ?? MagicDnsAuto(assignedAddress: _assignedAddress);
  }

  final NetworkStore store;
  final NetworkBackend backend;

  /// The system DNS of the networks this service runs.
  late final MagicDnsSetup magicDns;
  final void Function(String message) log;
  IpcServer? _server;

  /// The DNS setups still running, and the networks stopping under them.
  final _dnsRuns = <String, Future<void>>{};
  final _dnsStopping = <String>{};

  /// Serves the app on [socket], admitting peers that present [token], then
  /// starts the networks marked to start on boot.
  Future<void> start(ServerSocket socket, {String? token}) async {
    _server = IpcServer(socket, methods: _methods, token: token);
    log('Serving on ${socket.address.address}');
    await _autoStart();
  }

  /// Stops serving, reverts the DNS it configured, and stops every instance.
  Future<void> stop() async {
    await _server?.close();
    _dnsStopping.addAll(_dnsRuns.keys);
    await _revertAllDns();
    await backend.dispose();
    log('Stopped');
  }

  Future<void> _autoStart() async {
    for (final MapEntry(:key, :value) in (await _savedNetworks()).entries) {
      if (!value.autoStart) continue;
      try {
        await backend.start(key, value);
        _startDns(key, value);
        log('Started ${value.networkName}');
      } catch (error) {
        log('Could not start ${value.networkName}: $error');
      }
    }
  }

  Map<String, IpcMethod> get _methods => {
    'version': (_) => serviceVersion,
    'collect': (_) => backend.collectInfos(),
    'start': (params) => _start(params['id'].asString),
    'stop': (params) => _stop(_names(params)),
  };

  Future<void> _start(String id) async {
    // Read afresh: the app saves edits right before starting a network.
    final network = (await _savedNetworks())[id];
    if (network == null) {
      throw RpcException.invalidParams('Network $id is not saved');
    }
    await backend.start(id, network);
    _startDns(id, network);
    log('Started ${network.networkName}');
  }

  /// Reverts the DNS of the networks about to stop, while their TUN devices
  /// still exist, then stops their instances.
  Future<void> _stop(List<String> names) async {
    for (final MapEntry(:key, :value) in (await _savedNetworks()).entries) {
      if (!names.contains(value.networkName)) continue;
      _dnsStopping.add(key);
      await _revertDns(key, value.networkName);
    }
    await backend.stop(names);
  }

  /// Sets the DNS up in the background: waiting for a TUN device that is still
  /// coming up (or never comes) must not hold up the app's start request or
  /// the networks started after it.
  void _startDns(String id, Network network) {
    _dnsStopping.remove(id);
    final run = _applyDns(id, network);
    _dnsRuns[id] = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_dnsRuns[id], run)) _dnsRuns.remove(id);
      }),
    );
  }

  Future<void> _applyDns(String id, Network network) async {
    try {
      final interface = await magicDns.start(id, network);
      // The network stopped while its interface was still coming up.
      if (_dnsStopping.contains(id)) {
        await _revertDns(id, network.networkName);
        return;
      }
      if (interface != null) {
        log('Magic DNS set up for ${network.networkName} on $interface');
      }
    } catch (error) {
      log('Could not set Magic DNS up for ${network.networkName}: $error');
    }
  }

  Future<void> _revertDns(String id, String networkName) async {
    try {
      await magicDns.revert(id);
    } catch (error) {
      log('Could not revert Magic DNS for $networkName: $error');
    }
  }

  Future<void> _revertAllDns() async {
    try {
      await magicDns.revertAll();
    } catch (error) {
      log('Could not revert Magic DNS: $error');
    }
  }

  /// The virtual IPv4 EasyTier assigned to the instance running as [id].
  ///
  /// A network configured for DHCP carries no address of its own, so Magic DNS
  /// asks the running instance. Null when the collection fails: a setup then
  /// finds no interface and waits, rather than breaking the network's start.
  Future<String?> _assignedAddress(String id) async {
    try {
      final instances = await backend.collect(await _savedNetworks());
      return instances[id]?.myself?.virtualIpv4;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Network>> _savedNetworks() async {
    try {
      return await store.load();
    } catch (error) {
      log('Could not read ${store.file.path}: $error');
      return const {};
    }
  }

  static List<String> _names(Parameters params) => [
    for (final name in params['names'].asList)
      if (name is String)
        name
      else
        throw RpcException.invalidParams('Instance names must be strings'),
  ];
}

void _log(String message) => stderr.writeln(message);

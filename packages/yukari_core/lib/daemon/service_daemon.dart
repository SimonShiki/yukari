import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart' show Parameters, RpcException;

import '../backend/backend.dart';
import '../backend/ipc/ipc_server.dart';
import '../backend/service_version.dart';
import '../models/models.dart';
import '../storage/network_store.dart';
import '../system/magic_dns.dart';
import '../system/magic_dns_auto.dart';
import '../system/udp_broadcast_relay.dart';
import 'network_policy.dart';

/// The background service: serves [backend] to the app over IPC and starts
/// the networks marked [Network.autoStart] when it comes up.
///
/// It also configures the system DNS for platforms EasyTier cannot configure
/// itself (the Android root service): Windows and Linux are handled natively by
/// EasyTier. Networks are read from [store], which the app owns; the service
/// never writes it and only starts networks saved there.
final class ServiceDaemon {
  ServiceDaemon({
    required this.store,
    required this.backend,
    MagicDnsSetup? magicDns,
    MagicDnsPlatform? dnsPlatform,
    UdpBroadcastRelaySetup? udpBroadcastRelay,
    this.log = _log,
  }) : assert(store.readOnly, 'The service must not write the network store') {
    this.magicDns =
        magicDns ??
        MagicDnsAuto(
          system: MagicDnsSystem(platform: dnsPlatform),
          assignedAddress: _assignedAddress,
        );
    this.udpBroadcastRelay =
        udpBroadcastRelay ??
        UdpBroadcastRelayAuto(assignedAddress: _assignedAddress, log: log);
  }

  final NetworkStore store;
  final NetworkBackend backend;

  /// The system DNS of the networks this service runs.
  late final MagicDnsSetup magicDns;
  late final UdpBroadcastRelaySetup udpBroadcastRelay;
  final _relayStarts = <String, ({String name, Object token})>{};
  bool _shuttingDown = false;
  final void Function(String message) log;
  IpcServer? _server;

  /// The DNS setups still running, and the networks stopping under them.
  final _dnsRuns = <String, Future<void>>{};
  final _dnsStopping = <String>{};
  final _runningNames = <String, String>{};

  /// Serves the app on [socket], admitting peers that [admits] lets in and
  /// that present [token], then starts the networks marked to start on boot.
  Future<void> start(
    ServerSocket socket, {
    String? token,
    bool Function(Socket peer)? admits,
  }) async {
    _server = IpcServer(
      socket,
      methods: _methods,
      token: token,
      admits: admits,
    );
    log('Serving on ${socket.address.address}');
    await _autoStart();
  }

  /// Stops serving, reverts the DNS it configured, and stops every instance.
  Future<void> stop() async {
    _shuttingDown = true;
    await _server?.close();
    _runningNames.clear();
    _relayStarts.clear();
    await _stopBroadcastRelays();
    _dnsStopping.addAll(_dnsRuns.keys);
    await _revertAllDns();
    await backend.dispose();
    log('Stopped');
  }

  Future<void> _autoStart() async {
    for (final MapEntry(:key, :value) in (await _savedNetworks()).entries) {
      if (!value.autoStart) continue;
      try {
        await _launch(key, value);
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
    await _launch(id, network);
  }

  /// Runs [network] as [id], unless it sets what root must not do for the
  /// user; see [privilegedSetting].
  Future<void> _launch(String id, Network network) async {
    if (privilegedSetting(network) case final reason?) {
      throw RpcException.invalidParams(
        'The service will not run ${network.networkName}: $reason',
      );
    }
    await backend.start(id, network);
    _runningNames[id] = network.networkName;
    _startDns(id, network);
    unawaited(_startBroadcastRelay(id, network));
    log('Started ${network.networkName}');
  }

  /// Clears relay and DNS state while the TUN devices still exist.
  Future<void> _stop(List<String> names) async {
    final stopped = <String, String>{};
    _runningNames.removeWhere((id, name) {
      if (!names.contains(name)) return false;
      stopped[id] = name;
      return true;
    });
    for (final MapEntry(:key, :value) in _relayStarts.entries.toList()) {
      if (!names.contains(value.name)) continue;
      _relayStarts.remove(key);
      await _stopBroadcastRelays(key);
    }
    if (stopped.length < names.toSet().length) {
      for (final MapEntry(:key, :value) in (await _savedNetworks()).entries) {
        if (names.contains(value.networkName)) {
          stopped.putIfAbsent(key, () => value.networkName);
        }
      }
    }
    for (final MapEntry(:key, :value) in stopped.entries) {
      _dnsStopping.add(key);
      await _revertDns(key, value);
    }
    await backend.stop(names);
  }

  Future<void> _startBroadcastRelay(String id, Network network) async {
    if (_shuttingDown || !udpBroadcastRelay.appliesTo(network)) {
      _relayStarts.remove(id);
      await _stopBroadcastRelays(id);
      return;
    }
    final run = _relayStarts[id] = (name: network.networkName, token: Object());
    try {
      final interface = await udpBroadcastRelay.start(id, network);
      if (_relayStarts[id] == run) {
        if (interface != null) {
          log(
            'UDP broadcast relay set up for ${network.networkName} on $interface',
          );
        } else {
          _relayStarts.remove(id);
        }
      } else if (!_relayStarts.containsKey(id)) {
        await _stopBroadcastRelays(id);
      }
    } catch (error) {
      if (_relayStarts[id] == run) _relayStarts.remove(id);
      log(
        'Could not start UDP broadcast relay for ${network.networkName}: $error',
      );
    }
  }

  Future<void> _stopBroadcastRelays([String? id]) async {
    try {
      if (id == null) {
        await udpBroadcastRelay.stopAll();
      } else {
        await udpBroadcastRelay.stop(id);
      }
    } catch (error) {
      log('Could not stop UDP broadcast relay: $error');
    }
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

  /// The virtual address EasyTier assigned to the instance running as [id].
  ///
  /// A network configured for DHCP carries no address of its own, so Magic DNS
  /// asks the running instance. Null when the collection fails: a setup then
  /// finds no interface and waits, rather than breaking the network's start.
  Future<String?> _assignedAddress(String id) async {
    try {
      final infos = await backend.collectInfos();
      final name = _runningNames[id] ?? (await _savedNetworks())[id]?.networkName;
      if (name == null) return null;
      final info = infos[name];
      if (info == null) return null;
      final json = jsonDecode(info) as Map<String, Object?>;
      final myNodeInfo = json['my_node_info'] as Map<String, Object?>?;
      if (myNodeInfo == null) return null;
      return Peer.ipv4FromInet(myNodeInfo['virtual_ipv4']) ??
          Peer.ipv6FromInet(myNodeInfo['virtual_ipv6']);
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

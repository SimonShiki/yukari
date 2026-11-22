import 'dart:async';
import 'dart:io';

import 'package:signals/signals.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/udp_broadcast_relay.dart';

import 'backend.dart' as backends;
import 'instances.dart' as running;

/// Tracks relay targets belonging to the app backend.
final class AppUdpBroadcastRelayAuto {
  AppUdpBroadcastRelayAuto({
    UdpBroadcastRelaySetup? setup,
    ReadonlySignal<BackendKind>? backendKind,
  }) : setup =
           setup ??
           UdpBroadcastRelayAuto(
             assignedAddress: (id) async =>
                 running.instances.peek()[id]?.myself?.virtualIpv4,
           ),
       backendKind = backendKind ?? backends.backendKind {
    _stop = effect(_sync);
  }

  final UdpBroadcastRelaySetup setup;
  final ReadonlySignal<BackendKind> backendKind;
  final _started = <String>{};
  late final void Function() _stop;

  Future<void> dispose() {
    _stop();
    _started.clear();
    return setup.stopAll();
  }

  void _sync() {
    final instances = running.instances.value;
    final active = backendKind.value == BackendKind.ffi;
    for (final id in _started.toList()) {
      if (!active || instances[id]?.status != InstanceStatus.running) {
        _started.remove(id);
        unawaited(setup.stop(id));
      }
    }
    if (!active) return;
    for (final MapEntry(:key, :value) in instances.entries) {
      if (value.status != InstanceStatus.running) continue;
      if (_started.contains(key)) continue;
      if (!setup.appliesTo(value.network)) continue;
      _started.add(key);
      unawaited(setup.start(key, value.network));
    }
  }
}

void initUdpBroadcastRelayAuto() {
  if (Platform.isLinux) AppUdpBroadcastRelayAuto();
}

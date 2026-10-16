import 'dart:convert';

import 'package:signals/signals.dart';
import 'package:yukari/backend/backend.dart';
import 'package:yukari/models/models.dart';

/// A backend that pretends to run instances, recording what it was asked.
class FakeBackend extends NetworkBackend {
  FakeBackend({this.collected, this.maxInstances});

  /// EasyTier information by instance name; defaults to the started ones.
  final Map<String, Object?> Function()? collected;
  final started = <String, Network>{};
  final stopped = <String>[];
  Object? startError;
  TunAccess access = TunAccess.granted;

  @override
  final int? maxInstances;

  @override
  BackendKind get kind => BackendKind.ffi;

  @override
  final ReadonlySignal<BackendStatus> status = signal(BackendStatus.ready);

  @override
  Future<Map<String, String>> collectInfos() async => {
    for (final MapEntry(:key, :value)
        in (collected?.call() ??
                {
                  for (final network in started.values)
                    network.networkName: {'running': true},
                })
            .entries)
      key: jsonEncode(value),
  };

  @override
  Future<void> start(String id, Network network) async {
    if (startError case final error?) throw error;
    started[id] = network;
  }

  @override
  Future<void> stop(List<String> names) async {
    stopped.addAll(names);
    started.removeWhere((_, network) => names.contains(network.networkName));
  }

  @override
  Future<TunAccess> tunAccess(Network network) async => access;

  @override
  Future<void> dispose() async {}
}

/// A backend that counts its collections, and can be made to fail them.
class CountingBackend extends FakeBackend {
  CountingBackend({super.collected, this.failCollect = false});

  /// Whether [collectInfos] throws instead of returning.
  final bool failCollect;

  /// How often [collectInfos] was called.
  int collects = 0;

  @override
  Future<Map<String, String>> collectInfos() async {
    collects++;
    if (failCollect) throw Exception('boom');
    return super.collectInfos();
  }
}

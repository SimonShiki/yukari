import 'dart:async';
import 'dart:math';

import 'package:signals/signals.dart';

import '../backend/backend.dart';
import '../backend/ipc/ipc_client.dart';
import '../backend/ipc/ipc_endpoint.dart';
import '../models/models.dart';
import '../signals/backend.dart';
import '../signals/networks.dart';
import '../utils/stun_probe.dart';

/// Bytes the running networks exchanged with their peers so far, and how many
/// per second since the previous refresh.
typedef Traffic = ({
  int received,
  int sent,
  double receiveRate,
  double sendRate,
});

/// The NAT type, and whether EasyTier reported it rather than [probeNat].
typedef NatReport = ({NatType type, bool reported});

/// Gathers what the home dashboard shows while it is on screen.
class HomeController {
  HomeController({
    NetworkBackend? backend,
    Future<NatProbe> Function()? probe,
    Future<int?> Function()? probeServiceVersion,
    this.refreshInterval = const Duration(seconds: 2),
  }) : _injected = backend,
       _probe = probe ?? probeNat,
       _probeServiceVersion = probeServiceVersion ?? _runningServiceVersion;

  final Duration refreshInterval;
  final NetworkBackend? _injected;
  final Future<NatProbe> Function() _probe;
  final Future<int?> Function() _probeServiceVersion;
  final _clock = Stopwatch()..start();
  void Function()? _unsubscribe;
  Timer? _timer;
  bool _refreshing = false;
  ({int received, int sent, Duration at})? _lastTotals;

  final instances = signal<Map<String, Instance>>({});

  /// Whether the first refresh is done, until which cards show skeletons.
  final refreshed = signal(false);
  final traffic = signal<Traffic?>(null);
  final natProbe = signal<NatProbe?>(null);
  final probing = signal(false);

  /// The version the background service reports, when it is the backend.
  final serviceVersion = signal<int?>(null);

  NetworkBackend get _backend => _injected ?? backend.value;

  late final kind = computed(() => _backend.kind);
  late final status = computed(() => _backend.status.value);

  late final easyTierVersion = computed(
    () => instances.value.values.map((i) => i.version).nonNulls.firstOrNull,
  );

  /// EasyTier's own detection when a network runs, as it tests more servers.
  late final nat = computed<NatReport?>(() {
    for (final instance in instances.value.values) {
      if (instance.myself?.natType case final type?
          when type != NatType.unknown) {
        return (type: type, reported: true);
      }
    }
    return switch (natProbe.value) {
      final probe? => (type: probe.natType, reported: false),
      null => null,
    };
  });

  /// Addresses in the virtual networks, by network name, with the name
  /// Magic DNS resolves to them where the network enables it.
  late final virtualAddresses = computed(
    () => [
      for (final instance in instances.value.values)
        if (instance.myself?.virtualIpv4 case final address?)
          (
            network: instance.network.networkName,
            address: address,
            host: _magicDnsName(instance),
          ),
    ],
  );

  /// Such as `host-b.et.net`, from the hostname EasyTier runs with.
  static String? _magicDnsName(Instance instance) {
    final flags = instance.network.flags;
    final hostname = instance.myself?.hostname ?? '';
    final zone = flags.dnsZone.endsWith('.')
        ? flags.dnsZone.substring(0, flags.dnsZone.length - 1)
        : flags.dnsZone;
    if (!flags.acceptDns || hostname.isEmpty || zone.isEmpty) return null;
    return '$hostname.$zone';
  }

  void start() {
    _unsubscribe ??= effect(() {
      networks.value;
      final backend = _backend; // Again when the user switches backends.
      backend.status.value;
      untracked(() {
        unawaited(refresh());
        unawaited(_checkServiceVersion(backend));
      });
    });
    _timer ??= Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    unawaited(detectNat());
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final collected = await _backend.collect(networks.peek());
      batch(() {
        instances.value = collected;
        traffic.value = _measure(collected.values);
      });
    } catch (_) {
      // The header shows the backend unreachable.
      batch(() {
        instances.value = const {};
        traffic.value = null;
      });
    } finally {
      _refreshing = false;
      refreshed.value = true;
    }
  }

  Future<void> detectNat() async {
    if (probing.peek()) return;
    probing.value = true;
    try {
      natProbe.value = await _probe();
    } catch (_) {
      natProbe.value = const NatProbe(
        publicAddress: null,
        natType: NatType.unknown,
      );
    } finally {
      probing.value = false;
    }
  }

  Traffic? _measure(Iterable<Instance> running) {
    if (running.isEmpty) {
      _lastTotals = null;
      return null;
    }
    final peers = running.expand((instance) => instance.peers);
    final received = peers.fold(0, (sum, peer) => sum + peer.rxBytes);
    final sent = peers.fold(0, (sum, peer) => sum + peer.txBytes);
    final now = _clock.elapsed;
    final last = _lastTotals;
    _lastTotals = (received: received, sent: sent, at: now);
    if (last == null) {
      return (received: received, sent: sent, receiveRate: 0, sendRate: 0);
    }
    final seconds = (now - last.at).inMicroseconds / 1e6;
    // Counters restart when peers reconnect, so a drop is no traffic.
    double rate(int current, int previous) =>
        seconds <= 0 ? 0 : max(0, current - previous) / seconds;
    return (
      received: received,
      sent: sent,
      receiveRate: rate(received, last.received),
      sendRate: rate(sent, last.sent),
    );
  }

  Future<void> _checkServiceVersion(NetworkBackend backend) async {
    if (backend.kind != BackendKind.service ||
        backend.status.peek() != BackendStatus.ready) {
      serviceVersion.value = null;
      return;
    }
    try {
      serviceVersion.value = await _probeServiceVersion();
    } catch (_) {
      serviceVersion.value = null;
    }
  }

  static Future<int?> _runningServiceVersion() async =>
      runningServiceVersion(await IpcEndpoint.locate(serviceControl.dataDir));

  void dispose() {
    _unsubscribe?.call();
    _timer?.cancel();
    kind.dispose();
    status.dispose();
    easyTierVersion.dispose();
    nat.dispose();
    virtualAddresses.dispose();
  }
}

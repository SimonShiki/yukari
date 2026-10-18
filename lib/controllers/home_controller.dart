import 'dart:async';
import 'dart:math';

import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';
import '../backend/ipc/ipc_client.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari_core/models/models.dart';
import '../signals/backend.dart' as active;
import '../signals/instances.dart' as running;
import '../signals/networks.dart';
import 'package:yukari_core/system/magic_dns.dart';
import '../utils/stun_probe.dart';

part 'home_actions.dart';
part 'home_address.dart';
part 'home_traffic.dart';

/// The Home dashboard's state: every signal the page reads, as a small
/// primitive, so a change rebuilds the one label that shows it (AGENTS.md
/// § Architecture).
///
/// The actions the page invokes live in `home_actions.dart`, the address
/// card's derivations in `home_address.dart` and the traffic measurement in
/// `home_traffic.dart`.
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
  final _disposers = <void Function()>[];

  EffectCleanup? _effect;
  Timer? _timer;
  bool _started = false;
  bool _refreshing = false;
  bool _disposed = false;

  /// The last traffic sample, see [measureTraffic].
  TrafficSample? _traffic;

  Signal<T> _own<T>(T value) {
    final created = signal<T>(value);
    _disposers.add(created.dispose);
    return created;
  }

  Computed<T> _derive<T>(T Function() compute) {
    final created = computed<T>(compute);
    _disposers.add(created.dispose);
    return created;
  }

  /// The backend instances run in, or the injected one in tests.
  late final Computed<NetworkBackend> _activeBackend = _derive(
    () => _injected ?? active.backend.value,
  );

  // -- Backend header -------------------------------------------------------

  /// The active backend's status: the app-wide signal, or the injected
  /// backend's, which this controller then owns.
  late final ReadonlySignal<BackendStatus> status = _injected == null
      ? active.backendStatus
      : _derive(() => _activeBackend.value.status.value);
  late final ReadonlySignal<BackendKind> backendKind = _injected == null
      ? active.backendKind
      : _derive(() => _activeBackend.value.kind);
  late final Signal<int?> serviceVersion = _own<int?>(null);
  late final Computed<bool> showSettings = _derive(
    () => status.value == BackendStatus.unavailable,
  );
  late final Computed<String?> easyTierVersion = _derive(() {
    for (final instance in _running.value) {
      if (instance.version case final String version?) return version;
    }
    return null;
  });

  // -- Networks card --------------------------------------------------------

  late final Signal<bool> refreshed = _own(false);
  late final Computed<List<Instance>> _running = _derive(
    () => [
      for (final instance in running.instances.value.values)
        if (instance.status == InstanceStatus.running) instance,
    ],
  );
  late final Computed<int> savedCount = _derive(() => networks.value.length);
  late final Computed<int> runningCount = _derive(() => _running.value.length);
  late final Computed<String> runningNames = _derive(() => _names(', '));
  late final Computed<String> runningNamesMultiline = _derive(
    () => _names('\n'),
  );

  String _names(String separator) => _running.value
      .map((instance) => instance.network.networkName)
      .join(separator);

  // -- Address card ---------------------------------------------------------

  late final Signal<NatProbe?> _probeResult = _own<NatProbe?>(null);
  late final Computed<List<HomeAddressEntry>> _addresses = _derive(
    () => homeAddressesOf(_running.value),
  );
  late final Computed<AddressKind> addressKind = _derive(
    () => addressKindOf(refreshed.value, _addresses.value, _probeResult.value),
  );
  late final Computed<String?> address = _derive(
    () => addressOf(_addresses.value, _probeResult.value),
  );
  late final Computed<String> addressSupporting = _derive(
    () => addressSupportingOf(_addresses.value),
  );
  late final Computed<int> addressMoreCount = _derive(
    () => addressMoreCountOf(_addresses.value),
  );
  late final Computed<String?> addressTooltip = _derive(
    () => addressTooltipOf(_addresses.value),
  );

  // -- NAT card -------------------------------------------------------------

  late final Signal<bool> probing = _own(false);
  late final Computed<NatType?> natType = _derive(
    () => _reportedNat() ?? _probeResult.value?.natType,
  );
  late final Computed<bool> natReportedByEasytier = _derive(
    () => _reportedNat() != null,
  );

  /// The NAT type the first running instance reports, or null when none does.
  NatType? _reportedNat() {
    for (final instance in _running.value) {
      final nat = instance.myself?.natType;
      if (nat != null && nat != NatType.unknown) return nat;
    }
    return null;
  }

  // -- Traffic card ---------------------------------------------------------

  late final Signal<double> receiveRate = _own(0.0);
  late final Signal<double> sendRate = _own(0.0);
  late final Signal<int> totalReceived = _own(0);
  late final Signal<int> totalSent = _own(0);
  late final Computed<bool> trafficIdle = _derive(
    () => runningCount.value == 0,
  );

  /// Where the networks card leads: the list, or the creator when none saved.
  String get networksRoute =>
      savedCount.value == 0 ? '/networks/create' : '/networks';

  /// Re-measures [instances] against the previous sample.
  void _measure(Map<String, Instance> instances) {
    final sample = measureTraffic(instances, _traffic);
    _traffic = sample;
    receiveRate.value = sample.receiveRate;
    sendRate.value = sample.sendRate;
    totalReceived.value = sample.received;
    totalSent.value = sample.sent;
  }
}

/// The version the background service at the app's data directory runs.
Future<int?> _runningServiceVersion() async => runningServiceVersion(
  await IpcEndpoint.locate(active.serviceControl.dataDir),
);

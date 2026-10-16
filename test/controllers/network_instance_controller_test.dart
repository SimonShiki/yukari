import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';
import 'package:yukari/controllers/network_instance_controller.dart';
import 'package:yukari/models/log_entry.dart';
import 'package:yukari/signals/instance_logs.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  const version = '{"time":"2024-01-01T00:00:03Z","event":"ConnectionError"}';
  const peer = '{"time":"2024-01-01T00:00:02Z","event":{"PeerAdded":"2"}}';
  const tun = '{"time":"2024-01-01T00:00:01Z","event":"TunDeviceError"}';
  const listenerPrefix =
      '{"time":"2024-01-01T00:00:00Z","event":{"ListenerAdded":"tcp://0.0.0.0:11010"}}';

  test('refresh collects its own network and records the events', () async {
    await seedNetworks();
    final backend = FakeBackend(collected: () => {'alpha': _info});
    final controller = NetworkInstanceController(id: 'n1', backend: backend);
    addTearDown(controller.dispose);

    expect(controller.missing.value, isFalse);
    expect(controller.name.value, 'alpha');
    expect(controller.loaded.value, isFalse);

    await controller.refresh();

    expect(controller.loaded.value, isTrue);
    expect(controller.isRunning.value, isTrue);
    expect(
      controller.peerCards.value.map((card) => card.hostname),
      ['me', 'peer-b'],
    );
    expect(controller.peerCards.value.first.isSelf, isTrue);
    expect(controller.peerCards.value.last.tags, hasLength(2));
    expect(controller.peerCards.value.last.latencyMs, 5);
  });

  test('an unknown network is missing and collects nothing', () async {
    await seedNetworks();
    final backend = FakeBackend(collected: () => {'alpha': _info});
    final controller = NetworkInstanceController(id: 'gone', backend: backend);
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.missing.value, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(controller.peerCards.value, isEmpty);
  });

  test('a failed refresh keeps the last known state', () async {
    await seedNetworks();
    final backend = _FlakyBackend();
    final controller = NetworkInstanceController(id: 'n1', backend: backend);
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.isRunning.value, isTrue);

    backend.fail = true;
    await controller.refresh();

    expect(controller.isRunning.value, isTrue);
    expect(controller.loaded.value, isTrue);
  });

  test('counts and filters the logs', () async {
    await seedNetworks();
    final controller = NetworkInstanceController(id: 'n1');
    addTearDown(controller.dispose);
    recordInstanceEvents('n1', [version, peer, tun, listenerPrefix]);
    addTearDown(() => clearInstanceLogs('n1'));

    expect(controller.count(LogFilter.all).value, 4);
    expect(controller.count(LogFilter.errors).value, 2);
    expect(controller.count(LogFilter.peers).value, 1);
    expect(controller.count(LogFilter.connections).value, 1);
    expect(controller.count(LogFilter.listeners).value, 1);

    expect(controller.visibleLogs.value, hasLength(4));
    controller.selectFilter(LogFilter.errors);
    expect(controller.visibleLogs.value, hasLength(2));
    expect(
      controller.visibleLogs.value.every(
        (entry) => entry.severity == LogSeverity.error,
      ),
      isTrue,
    );
    controller.selectFilter(LogFilter.listeners);
    expect(controller.visibleLogs.value.single.kind, 'ListenerAdded');
  });

  test('selectTab writes the route signal and follows it back', () async {
    await seedNetworks();
    final tab = signal(InstanceTab.logs);
    addTearDown(tab.dispose);
    final controller = NetworkInstanceController(
      id: 'n1',
      initialTab: InstanceTab.peers,
      tab: tab,
      backend: FakeBackend(),
    );
    addTearDown(controller.dispose);

    // The route's tab wins at construction.
    expect(controller.selectedTab.value, InstanceTab.logs);

    controller.selectTab(InstanceTab.peers);

    expect(controller.selectedTab.value, InstanceTab.peers);
    expect(tab.value, InstanceTab.peers);

    tab.value = InstanceTab.logs;

    expect(controller.selectedTab.value, InstanceTab.logs);
  });

  test('a page without a route tab keeps its own selection', () async {
    await seedNetworks();
    final controller = NetworkInstanceController(
      id: 'n1',
      initialTab: InstanceTab.logs,
      backend: FakeBackend(),
    );
    addTearDown(controller.dispose);

    expect(controller.selectedTab.value, InstanceTab.logs);
    controller.selectTab(InstanceTab.peers);
    expect(controller.selectedTab.value, InstanceTab.peers);
  });

  test('entries expand and collapse', () async {
    await seedNetworks();
    final controller = NetworkInstanceController(id: 'n1');
    addTearDown(controller.dispose);
    final entry = LogEntry.parse(peer);

    expect(controller.isExpanded(entry), isFalse);
    controller.toggleExpanded(entry);
    expect(controller.isExpanded(entry), isTrue);
    controller.toggleExpanded(entry);
    expect(controller.isExpanded(entry), isFalse);
  });

  testWidgets('setActive refreshes now, then on the interval only while active', (
    tester,
  ) async {
    await tester.runAsync(seedNetworks);
    final backend = _CountingBackend();
    final controller = NetworkInstanceController(
      id: 'n1',
      backend: backend,
      refreshInterval: const Duration(seconds: 2),
    );
    addTearDown(controller.dispose);

    controller.setActive(true);
    await tester.pump();
    expect(backend.collects, 1);
    expect(controller.loaded.value, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(backend.collects, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(backend.collects, 3);

    controller.setActive(false);
    await tester.pump(const Duration(seconds: 4));
    expect(backend.collects, 3);
  });
}

/// The EasyTier information of one running instance with one peer.
final Map<String, Object?> _info = {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': 'me',
    'version': '2.7.0',
    'stun_info': {'udp_nat_type': 'FullCone'},
    'virtual_ipv4': {
      'address': {'addr': (10 << 24) | (144 << 16) | 1},
    },
  },
  'peer_route_pairs': [
    {
      'route': {
        'peer_id': 2,
        'hostname': 'peer-b',
        'next_hop_peer_id': 2,
        'ipv4_addr': {
          'address': {'addr': (10 << 24) | (144 << 16) | 2},
        },
        'stun_info': {'udp_nat_type': 'PortRestricted'},
      },
      'peer': {
        'conns': [
          {
            'peer_identity_type': 'Credential',
            'secure_auth_level': 'PeerVerified',
            'tunnel': {'tunnel_type': 'tcp'},
            'stats': {
              'latency_us': '5000',
              'rx_bytes': '1',
              'tx_bytes': '2',
              'rx_packets': '3',
              'tx_packets': '4',
            },
          },
        ],
      },
    },
  ],
};

/// A backend that can start failing.
class _FlakyBackend extends FakeBackend {
  _FlakyBackend() : super(collected: () => {'alpha': _info});

  bool fail = false;

  @override
  Future<Map<String, String>> collectInfos() async {
    if (fail) throw Exception('lost');
    return super.collectInfos();
  }
}

/// A backend that counts how often it was asked to collect.
class _CountingBackend extends FakeBackend {
  _CountingBackend() : super(collected: () => {'alpha': _info});

  int collects = 0;

  @override
  Future<Map<String, String>> collectInfos() async {
    collects++;
    return super.collectInfos();
  }
}

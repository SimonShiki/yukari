// The service these tests talk to listens on a Unix domain socket, which
// Windows does not have.
@TestOn('linux')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/backend/ipc/ipc_client.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari/backend/service_backend.dart';
import 'package:yukari_core/backend/service_version.dart';
import 'package:yukari_core/daemon/service_daemon.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/storage/network_store.dart';
import 'package:yukari_core/system/magic_dns_auto.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  late NetworkStore store;
  late FakeBackend runtime;
  late ServiceDaemon daemon;
  late ServiceBackend client;
  late int locates;
  late _FakeMagicDnsSetup magicDns;
  final logs = <String>[];

  Future<void> serve() async {
    final path = p.join(p.dirname(store.file.path), 'service.sock');
    final address = InternetAddress(path, type: InternetAddressType.unix);
    daemon = ServiceDaemon(
      store: NetworkStore(store.file, readOnly: true),
      backend: runtime,
      magicDns: magicDns,
      log: logs.add,
    );
    await daemon.start(await ServerSocket.bind(address, 0));
    client = ServiceBackend(() async {
      locates++;
      return IpcEndpoint(address, 0);
    });
    addTearDown(() async {
      await client.dispose();
      await daemon.stop();
    });
  }

  setUp(() async {
    logs.clear();
    locates = 0;
    magicDns = _FakeMagicDnsSetup();
    store = temporaryStore();
    runtime = FakeBackend();
    await store.save({
      'n1': Network()..networkName = 'alpha',
      'n2': Network()
        ..networkName = 'beta'
        ..autoStart = true,
    });
  });

  test('starts the networks marked to start on boot', () async {
    await serve();
    expect(runtime.started.keys, ['n2']);
    expect(magicDns.started, isEmpty, reason: 'no Magic DNS asked for');
  });

  test('sets Magic DNS up for a network it starts', () async {
    await store.save({'n1': _dnsNetwork('alpha')});
    await serve();

    await client.start('n1', Network());

    expect(magicDns.started, ['n1']);
  });

  test('sets Magic DNS up for boot networks, and skips no-TUN ones', () async {
    await store.save({
      'n1': _dnsNetwork('boot')..autoStart = true,
      'n2': _dnsNetwork('no-tun')
        ..autoStart = true
        ..flags.noTun = true,
    });
    await serve();

    expect(magicDns.started, ['n1']);
  });

  test('a start request does not wait for its Magic DNS setup', () async {
    await store.save({'n1': _dnsNetwork('alpha')});
    await serve();
    magicDns.gate = Completer<String?>();

    await client.start('n1', Network()).timeout(const Duration(seconds: 5));

    expect(magicDns.started, ['n1']);
    expect(
      magicDns.gate!.isCompleted,
      isFalse,
      reason: 'the RPC returned while the setup still waited for its interface',
    );

    await client.stop(['alpha']);
    expect(magicDns.reverted, contains('n1'));

    // The interface appears after the stop: the run reverts what it set up.
    magicDns.gate!.complete('et_n1');
    await Future<void>.delayed(Duration.zero);

    expect(
      magicDns.applied,
      isEmpty,
      reason: 'the run that finished after the stop reverted its own interface',
    );
    expect(
      magicDns.reverted.where((id) => id == 'n1'),
      hasLength(2),
      reason: 'the stop request and the late-finishing run both reverted',
    );

    // The service stop still reverts everything the setup owns.
    await daemon.stop();
    expect(magicDns.revertAllCalls, 1);
  });

  test('boot auto-start does not wait for the Magic DNS setups', () async {
    await store.save({
      'n1': _dnsNetwork('first')..autoStart = true,
      'n2': _dnsNetwork('second')..autoStart = true,
    });
    magicDns.gate = Completer<String?>();

    await serve().timeout(const Duration(seconds: 5));

    expect(runtime.started.keys, [
      'n1',
      'n2',
    ], reason: 'the next network starts while the first DNS setup waits');
    expect(magicDns.started, ['n1', 'n2']);

    magicDns.gate!.complete(null);
    await Future<void>.delayed(Duration.zero);
  });

  test('reverts Magic DNS when a network stops', () async {
    await store.save({'n1': _dnsNetwork('alpha')});
    await serve();
    await client.start('n1', Network());

    await client.stop(['alpha']);

    expect(magicDns.reverted, ['n1']);
  });

  test('reverts every DNS it set up when the service stops', () async {
    await store.save({'n1': _dnsNetwork('alpha')});
    await serve();
    await client.start('n1', Network());

    await daemon.stop();

    expect(magicDns.revertAllCalls, 1);
  });

  test('runs saved networks by id and reports them to the app', () async {
    await serve();
    await client.start('n1', Network()..networkName = 'ignored');

    expect(runtime.started['n1']!.networkName, 'alpha');
    final networks = await store.load();
    final instances = await client.collect(networks);
    expect(instances.keys, unorderedEquals(['n1', 'n2']));
    expect(instances['n1']!.status, InstanceStatus.running);
    expect(client.status.value, BackendStatus.ready);
  });

  test('reads edits the app saved before starting', () async {
    await serve();
    await store.save({'n1': Network()..networkName = 'edited'});
    await client.start('n1', Network());
    expect(runtime.started['n1']!.networkName, 'edited');
  });

  test('refuses networks that are not saved', () async {
    await serve();
    await expectLater(client.start('nope', Network()), throwsException);
    expect(runtime.started.keys, isNot(contains('nope')));
  });

  test('stops instances by name', () async {
    await serve();
    await client.stop(['beta']);
    expect(runtime.stopped, ['beta']);
    expect(await client.collectInfos(), isEmpty);
  });

  test('reports its version, or none when it is unreachable', () async {
    await serve();
    final path = p.join(p.dirname(store.file.path), 'service.sock');
    final address = InternetAddress(path, type: InternetAddressType.unix);
    expect(
      await runningServiceVersion(IpcEndpoint(address, 0)),
      serviceVersion,
    );
    await daemon.stop();
    expect(await runningServiceVersion(IpcEndpoint(address, 0)), isNull);
  });

  test('opens the connection again without announcing a new check', () async {
    var checks = 0;
    final backend = ServiceBackend(() async {
      checks++;
      return IpcEndpoint(_missingAddress(store), 0);
    });
    addTearDown(backend.dispose);

    await expectLater(backend.collectInfos(), throwsException);
    expect(backend.status.value, BackendStatus.unavailable);

    // The next request tries the service again, but a check that fails again is
    // not announced as a new one: the pages showing the status must not flicker.
    final pending = backend.collectInfos();
    expect(backend.status.value, BackendStatus.unavailable);

    await expectLater(pending, throwsException);
    expect(checks, greaterThan(1), reason: 'the endpoint is read again');
    expect(backend.status.value, BackendStatus.unavailable);
  });

  test('finds the service again after it restarts', () async {
    await serve();
    await client.collectInfos();
    final socket = File(p.join(p.dirname(store.file.path), 'service.sock'));
    Future<void> until(BackendStatus status) async {
      for (var i = 0; client.status.value != status; i++) {
        if (i == 100) fail('Status stayed ${client.status.value}');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await daemon.stop();
    await until(BackendStatus.unavailable);
    if (await socket.exists()) await socket.delete();
    final restarted = ServiceDaemon(
      store: NetworkStore(store.file, readOnly: true),
      backend: FakeBackend(),
      log: logs.add,
    );
    await restarted.start(
      await ServerSocket.bind(
        InternetAddress(socket.path, type: InternetAddressType.unix),
        0,
      ),
    );
    addTearDown(restarted.stop);
    final published = locates;

    // Nothing reaches out on its own. The next request is what finds the
    // service that came back, at the endpoint it published when it restarted.
    await client.collectInfos();

    expect(
      locates,
      greaterThan(published),
      reason: 'the endpoint is read again, not reused',
    );
    expect(client.status.value, BackendStatus.ready);
  });

  test('reports the service as unavailable when it is not running', () async {
    final missing = InternetAddress(
      p.join(p.dirname(store.file.path), 'missing.sock'),
      type: InternetAddressType.unix,
    );
    final backend = ServiceBackend(() async => IpcEndpoint(missing, 0));
    addTearDown(backend.dispose);
    await expectLater(backend.collectInfos(), throwsException);
    expect(backend.status.value, BackendStatus.unavailable);
  });

  test('disposes its status with it', () async {
    final backend = ServiceBackend(
      () async => IpcEndpoint(_missingAddress(store), 0),
    );

    await backend.dispose();

    expect(backend.status.disposed, isTrue);
  });

  test('a service that answers after disposal cannot write the status', () async {
    final locate = Completer<IpcEndpoint>();
    final backend = ServiceBackend(() => locate.future);

    final pending = backend.collectInfos();
    await backend.dispose();
    locate.complete(IpcEndpoint(_missingAddress(store), 0));

    // The unreachable service is still reported as such: the status write in
    // the failure path is skipped, not thrown from.
    await expectLater(pending, throwsA(isA<ServiceUnavailableException>()));
  });

  test('the daemon never writes the store', () {
    expect(
      () => ServiceDaemon(store: store, backend: runtime),
      throwsA(isA<AssertionError>()),
    );
  });
}

/// A network with Magic DNS on.
Network _dnsNetwork(String name) => Network()
  ..networkName = name
  ..flags = (NetworkFlags()..acceptDns = true);

/// Records the Magic DNS setup the service asked for.
final class _FakeMagicDnsSetup implements MagicDnsSetup {
  final started = <String>[];
  final reverted = <String>[];
  final applied = <String, String>{};
  var revertAllCalls = 0;

  /// When set, [start] waits for it: a setup whose interface never appears.
  Completer<String?>? gate;

  @override
  bool appliesTo(Network network) =>
      network.flags.acceptDns && !network.flags.noTun;

  @override
  Future<String?> start(String networkId, Network network) async {
    if (!appliesTo(network)) return null;
    started.add(networkId);
    final waiting = gate;
    final interface = waiting == null ? 'et_$networkId' : await waiting.future;
    if (interface != null) applied[networkId] = interface;
    return interface;
  }

  @override
  Future<void> revert(String networkId) async {
    reverted.add(networkId);
    applied.remove(networkId);
  }

  @override
  Future<void> revertAll() async => revertAllCalls++;
}

/// An endpoint with no service listening beside [store].
InternetAddress _missingAddress(NetworkStore store) => InternetAddress(
  p.join(p.dirname(store.file.path), 'missing.sock'),
  type: InternetAddressType.unix,
);

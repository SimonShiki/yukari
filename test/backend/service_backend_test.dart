import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/backend/ipc/ipc_client.dart';
import 'package:yukari/backend/ipc/ipc_endpoint.dart';
import 'package:yukari/backend/service_backend.dart';
import 'package:yukari/backend/service_version.dart';
import 'package:yukari/daemon/service_daemon.dart';
import 'package:yukari/models/models.dart';
import 'package:yukari/storage/network_store.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

void main() {
  late NetworkStore store;
  late FakeBackend runtime;
  late ServiceDaemon daemon;
  late ServiceBackend client;
  late int locates;
  final logs = <String>[];

  Future<void> serve() async {
    final path = p.join(p.dirname(store.file.path), 'service.sock');
    final address = InternetAddress(path, type: InternetAddressType.unix);
    daemon = ServiceDaemon(
      store: NetworkStore(store.file, readOnly: true),
      backend: runtime,
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

/// An endpoint with no service listening beside [store].
InternetAddress _missingAddress(NetworkStore store) => InternetAddress(
  p.join(p.dirname(store.file.path), 'missing.sock'),
  type: InternetAddressType.unix,
);

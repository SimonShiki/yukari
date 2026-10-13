import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/backend/ipc/ipc_endpoint.dart';
import 'package:yukari/backend/service_backend.dart';
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
    client = ServiceBackend(() async => IpcEndpoint(address, 0));
    addTearDown(() async {
      await client.dispose();
      await daemon.stop();
    });
  }

  setUp(() async {
    logs.clear();
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

  test('the daemon never writes the store', () {
    expect(
      () => ServiceDaemon(store: store, backend: runtime),
      throwsA(isA<AssertionError>()),
    );
  });
}

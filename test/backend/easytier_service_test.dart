import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari_core/backend/ffi_backend.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari/backend/service_backend.dart';
import 'package:yukari_core/daemon/service_daemon.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../async_support.dart';
import '../networks_fixture.dart';

/// Runs real EasyTier instances through the service, without TUN devices so
/// no privileges are needed.
void main() {
  test('the service runs saved networks with EasyTier', () async {
    final store = temporaryStore();
    await store.save({
      'boot': Network()
        ..networkName = 'yukari-test-boot'
        ..autoStart = true
        ..flags.noTun = true,
      'manual': Network()
        ..networkName = 'yukari-test-manual'
        ..flags.noTun = true,
    });
    // The Linux service listens on a Unix socket, Windows on loopback.
    final socket = await ServerSocket.bind(
      Platform.isWindows
          ? InternetAddress.loopbackIPv4
          : InternetAddress(
              p.join(p.dirname(store.file.path), 'service.sock'),
              type: InternetAddressType.unix,
            ),
      0,
    );
    final endpoint = IpcEndpoint(socket.address, socket.port);
    final daemon = ServiceDaemon(
      store: NetworkStore(store.file, readOnly: true),
      backend: FfiBackend(),
      log: (_) {},
    );
    await daemon.start(socket);
    final client = ServiceBackend(() async => endpoint);
    addTearDown(() async {
      await client.dispose();
      await daemon.stop();
    });
    final saved = await store.load();

    expect((await client.collect(saved)).keys, ['boot']);

    await client.start('manual', saved['manual']!);
    // EasyTier starts the instance in the background: the start request
    // returns before the instance reports running, so the status is read
    // until it settles.
    await waitFor(
      () async =>
          (await client.collect(saved))['manual']?.status ==
          InstanceStatus.running,
    );
    final instances = await client.collect(saved);
    expect(instances.keys, unorderedEquals(['boot', 'manual']));
    expect(instances['manual']!.status, InstanceStatus.running);
    await expectLater(
      client.start('manual', saved['manual']!),
      throwsException,
      reason: 'EasyTier refuses a second instance of the same name',
    );

    await client.stop(['yukari-test-manual']);
    expect((await client.collect(saved)).keys, ['boot']);
  });
}

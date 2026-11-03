import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/service_backend.dart';
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari_core/daemon/network_policy.dart';
import 'package:yukari/utils/easytier_config_parser.dart';
import 'package:yukari_core/daemon/service_daemon.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../fake_backend.dart';
import '../networks_fixture.dart';

Network _named(String name) => Network()..networkName = name;

void main() {
  group('privilegedSetting', () {
    test('lets ordinary networks and plain namespaces run', () {
      expect(privilegedSetting(Network()), isNull);
      expect(privilegedSetting(Network()..netNamespace = 'lab-1'), isNull);
    });

    test('refuses a credential file, which root would write', () {
      expect(
        privilegedSetting(Network()..credentialFile = '/etc/cron.d/x'),
        contains('credential_file'),
      );
    });

    test('refuses file and RPC settings added as free-form configuration', () {
      for (final key in privilegedSettings) {
        final network = Network()..additionalConfiguration = {key: 'x'};
        expect(privilegedSetting(network), contains(key), reason: key);
      }
    });

    test('refuses privileged settings preserved from an imported config', () {
      final network = parseEasyTierConfig('''
network_identity = { network_name = "imported" }
file_logger = { dir = "/etc/cron.d" }
''');

      expect(network.additionalConfiguration['file_logger'], isNotNull);
      expect(privilegedSetting(network), contains('file_logger'));
    });

    test('refuses namespaces that are paths', () {
      for (final name in ['..', '.', '../../proc/1/ns/net', 'a/b']) {
        expect(
          privilegedSetting(Network()..netNamespace = name),
          isNotNull,
          reason: name,
        );
        expect(
          privilegedSetting(
            Network()..additionalConfiguration = {'netns': name},
          ),
          isNotNull,
          reason: 'free-form $name',
        );
      }
    });
  });

  group('the service', () {
    late NetworkStore store;
    late FakeBackend runtime;
    late ServiceBackend client;
    final logs = <String>[];

    Future<void> serve() async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final daemon = ServiceDaemon(
        store: NetworkStore(store.file, readOnly: true),
        backend: runtime,
        log: logs.add,
      );
      await daemon.start(socket);
      client = ServiceBackend(
        () async => IpcEndpoint(socket.address, socket.port),
      );
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
        'plain': _named('plain')..autoStart = true,
        'logger': _named('logger')
          ..autoStart = true
          ..additionalConfiguration = {
            'file_logger': {'dir': '/etc/cron.d'},
          },
      });
    });

    test('skips privileged settings on boot, and says why', () async {
      await serve();

      expect(runtime.started.keys, ['plain']);
      expect(logs, contains(contains('logger: it sets file_logger')));
    });

    test('refuses to start privileged settings on request', () async {
      await serve();

      await expectLater(client.start('logger', Network()), throwsException);
      expect(runtime.started.keys, ['plain']);
    });
  });
}

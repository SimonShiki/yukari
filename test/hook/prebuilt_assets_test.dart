import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_version.dart';
import '../../hook/prebuilt_assets.dart';

const String assetName = 'linux-x86_64-libeasytier_ffi.so';
const String fingerprint = 'fingerprint';
const String revision = '1649ec00135e12103e05bf543e0ed313d7e190f8';

void main() {
  group('fetchPrebuiltLibrary', () {
    final library = utf8.encode('the published library');
    late Directory directory;
    late Directory cache;
    late HttpServer server;
    late Uri manifestUrl;
    late Map<String, List<int>> release;
    late List<String> requests;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('prebuilt_assets_test');
      cache = await Directory('${directory.path}/cache').create();
      release = <String, List<int>>{};
      requests = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request.uri.path);
        final body = release[request.uri.path];
        if (body == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.add(body);
        }
        await request.response.close();
      });
      manifestUrl = Uri.parse('http://127.0.0.1:${server.port}/natives.json');
    });

    tearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });

    /// Publishes [bytes] and the manifest describing them.
    Future<void> publish({
      List<int>? bytes,
      String publishedFingerprint = fingerprint,
    }) async {
      final contents = bytes ?? library;
      final file = File('${directory.path}/published.so')
        ..writeAsBytesSync(contents);
      release['/$assetName'] = contents;
      release['/natives.json'] = utf8.encode(
        jsonEncode(
          NativeVersionManifest(
            generatedAt: '2026-08-27T10:00:00.000Z',
            assets: {
              assetName: NativeVersion(
                fingerprint: publishedFingerprint,
                easytier: revision,
                platform: 'linux',
                arch: 'x86_64',
                sha256: await sha256OfFile(file),
                builtAt: '2026-08-27T10:00:00.000Z',
              ),
            },
          ).toJson(),
        ),
      );
    }

    Future<Uri?> fetch() => fetchPrebuiltLibrary(
          assetName: assetName,
          fingerprint: fingerprint,
          cacheDirectory: cache,
          manifestUrl: manifestUrl,
        );

    test('downloads the published library and records its version', () async {
      await publish();

      final uri = await fetch();

      expect(uri, File.fromUri(cache.uri.resolve(assetName)).uri);
      expect(await File.fromUri(uri!).readAsBytes(), library);
      expect(requests, ['/natives.json', '/$assetName']);
      expect(await isNativeVersionCurrent(File.fromUri(uri), fingerprint), isTrue);
    });

    test('reuses a cached library without asking the release', () async {
      await publish();
      await fetch();
      requests.clear();

      expect(await fetch(), File.fromUri(cache.uri.resolve(assetName)).uri);
      expect(requests, isEmpty);
    });

    test('keeps a cached library that already matches the manifest', () async {
      await publish();
      File.fromUri(cache.uri.resolve(assetName)).writeAsBytesSync(library);

      expect(await fetch(), isNotNull);
      expect(requests, ['/natives.json']);
    });

    test('has no library for sources the release was not built from', () async {
      await publish(publishedFingerprint: 'other');

      expect(await fetch(), isNull);
      expect(requests, ['/natives.json']);
    });

    test('refuses a library that does not match the published digest', () async {
      await publish();
      release['/$assetName'] = utf8.encode('tampered with');

      await expectLater(fetch(), throwsA(isA<StateError>()));
      expect(File.fromUri(cache.uri.resolve(assetName)).existsSync(), isFalse);
    });

    test('reports a release without a version manifest', () async {
      await expectLater(fetch(), throwsA(isA<HttpException>()));
    });
  });

  group('windowsRuntimeLibrariesFor', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('windows_runtime_test');
    });

    tearDown(() => directory.delete(recursive: true));

    test('prefers the libraries a local build put next to the library', () async {
      final local = await Directory('${directory.path}/local').create();
      final cache = await Directory('${directory.path}/cache').create();
      for (final name in windowsRuntimeLibraries) {
        File('${local.path}/$name').writeAsBytesSync(utf8.encode(name));
      }

      final libraries = await windowsRuntimeLibrariesFor(
        localDirectory: local,
        cacheDirectory: cache,
        revision: revision,
      );

      expect(
        libraries.map((uri) => uri.pathSegments.last),
        windowsRuntimeLibraries,
      );
      for (final uri in libraries) {
        expect(File.fromUri(uri).parent.uri, local.uri);
      }
    });

    test('takes the libraries of the revision without a local build', () async {
      final cache = await Directory('${directory.path}/cache').create();
      final cached = await Directory('${cache.path}/$revision')
          .create(recursive: true);
      for (final name in windowsRuntimeLibraries) {
        File('${cached.path}/$name').writeAsBytesSync(utf8.encode(name));
      }

      final libraries = await windowsRuntimeLibrariesFor(
        localDirectory: null,
        cacheDirectory: cache,
        revision: revision,
      );

      expect(
        libraries.map((uri) => uri.pathSegments.last),
        windowsRuntimeLibraries,
      );
      for (final uri in libraries) {
        expect(File.fromUri(uri).parent.uri, cached.uri);
      }
    });
  });
}

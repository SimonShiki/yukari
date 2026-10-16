import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_library.dart';
import '../../hook/native_version.dart';

const String fingerprint = 'fingerprint';
const String revision = '1649ec00135e12103e05bf543e0ed313d7e190f8';

void main() {
  group('resolveNativeLibrary', () {
    late Directory directory;
    late File localLibrary;
    late File prebuiltLibrary;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('native_library_test');
      localLibrary = File('${directory.path}/libeasytier_ffi.so')
        ..writeAsBytesSync(const [1, 2, 3]);
      prebuiltLibrary = File('${directory.path}/prebuilt/libeasytier_ffi.so')
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [4, 5, 6]);
    });

    tearDown(() => directory.delete(recursive: true));

    Future<void> record(String recorded) async {
      await writeNativeVersion(
        localLibrary,
        await nativeVersionOf(
          library: localLibrary,
          fingerprint: recorded,
          easytier: revision,
          platform: 'linux',
          arch: 'x86_64',
          builtAt: DateTime.utc(2026, 8, 27, 10),
        ),
      );
    }

    Future<Uri> resolve({
      required Future<Uri?> Function() fetchPrebuilt,
      required Future<Uri> Function() buildLocally,
    }) =>
        resolveNativeLibrary(
          localLibrary: localLibrary,
          fingerprint: fingerprint,
          platform: 'linux',
          arch: 'x86_64',
          fetchPrebuilt: fetchPrebuilt,
          buildLocally: buildLocally,
        );

    test('uses a local build of the current sources', () async {
      await record(fingerprint);
      var fetched = false;
      var built = false;

      final uri = await resolve(
        fetchPrebuilt: () async {
          fetched = true;
          return prebuiltLibrary.uri;
        },
        buildLocally: () async {
          built = true;
          return prebuiltLibrary.uri;
        },
      );

      expect(uri, localLibrary.uri);
      expect(fetched, isFalse);
      expect(built, isFalse);
    });

    test('replaces a local build of other sources with the prebuilt one', () async {
      await record('older fingerprint');
      var built = false;

      final uri = await resolve(
        fetchPrebuilt: () async => prebuiltLibrary.uri,
        buildLocally: () async {
          built = true;
          return localLibrary.uri;
        },
      );

      expect(uri, prebuiltLibrary.uri);
      expect(built, isFalse);
    });

    test('builds locally when the release has nothing for the sources', () async {
      final uri = await resolve(
        fetchPrebuilt: () async => null,
        buildLocally: () async => localLibrary.uri,
      );

      expect(uri, localLibrary.uri);
    });

    test('builds locally when the release cannot be reached', () async {
      final uri = await resolve(
        fetchPrebuilt: () async => throw const HttpException('HTTP 404'),
        buildLocally: () async => localLibrary.uri,
      );

      expect(uri, localLibrary.uri);
    });

    test('names every source that failed when none works', () async {
      await expectLater(
        resolve(
          fetchPrebuilt: () async => null,
          buildLocally: () async => throw StateError('xmake is not installed'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('no prebuilt library'), contains('xmake is not installed')),
          ),
        ),
      );
    });
  });
}

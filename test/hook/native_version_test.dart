import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_version.dart';

const String sources = 'set_allowedarchs("linux|x86_64")\n'
    'add_versions(easytier_version, "1649ec00135e12103e05bf543e0ed313d7e190f8")\n';

void main() {
  group('nativeFingerprint', () {
    test('hashes the sources and the target', () {
      expect(
        nativeFingerprint(platform: 'linux', arch: 'x86_64', xmakeLua: sources),
        '1a9cd9c03152b43751c571b5ea366ac7d9656168',
      );
    });

    test('differs for other sources or another target', () {
      final fingerprint = nativeFingerprint(
        platform: 'linux',
        arch: 'x86_64',
        xmakeLua: sources,
      );
      expect(
        nativeFingerprint(platform: 'linux', arch: 'arm64', xmakeLua: sources),
        '0aebe0eedfa668f19e737a9216584ad49780baa7',
      );
      expect(
        nativeFingerprint(
          platform: 'android',
          arch: 'x86_64',
          xmakeLua: sources,
        ),
        '5899f0b86ae92923ee1e11a0b4aa60b58a3c2bb5',
      );
      expect(
        nativeFingerprint(
          platform: 'linux',
          arch: 'x86_64',
          xmakeLua: '$sources\n',
        ),
        isNot(fingerprint),
      );
    });

    test('names the same sources whatever the line endings are', () {
      expect(
        nativeFingerprint(
          platform: 'windows',
          arch: 'x64',
          xmakeLua: sources.replaceAll('\n', '\r\n'),
        ),
        nativeFingerprint(platform: 'windows', arch: 'x64', xmakeLua: sources),
      );
    });
  });

  group('easyTierRevision', () {
    test('reads the revision pinned by the sources', () {
      expect(
        easyTierRevision(sources),
        '1649ec00135e12103e05bf543e0ed313d7e190f8',
      );
      expect(
        easyTierRevision('add_resources(easytier_version, "vc-ltl", "url", '
            '"sha256")\n$sources'),
        '1649ec00135e12103e05bf543e0ed313d7e190f8',
      );
    });

    test('refuses sources that pin no revision', () {
      expect(
        () => easyTierRevision('add_versions(easytier_version, "0.1.0")'),
        throwsFormatException,
      );
      expect(() => easyTierRevision(''), throwsFormatException);
    });
  });

  group('native version', () {
    late Directory directory;
    late File library;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('native_version_test');
      library = File('${directory.path}/libeasytier_ffi.so')
        ..writeAsBytesSync(List<int>.generate(64, (index) => index));
    });

    tearDown(() => directory.delete(recursive: true));

    Future<NativeVersion> record(String fingerprint) => nativeVersionOf(
          library: library,
          fingerprint: fingerprint,
          easytier: '1649ec00135e12103e05bf543e0ed313d7e190f8',
          platform: 'linux',
          arch: 'x86_64',
          builtAt: DateTime.utc(2026, 8, 27, 10),
        );

    test('records the version of a library next to it', () async {
      final version = await record('fingerprint');
      await writeNativeVersion(library, version);

      expect(
        jsonDecode(File('${library.path}.version').readAsStringSync()),
        {
          'fingerprint': 'fingerprint',
          'easytier': '1649ec00135e12103e05bf543e0ed313d7e190f8',
          'platform': 'linux',
          'arch': 'x86_64',
          'sha256': version.sha256,
          'built_at': '2026-08-27T10:00:00.000Z',
        },
      );
      expect(await readNativeVersion(library), isNotNull);
      expect(await isNativeVersionCurrent(library, 'fingerprint'), isTrue);
    });

    test('a library of other sources is not current', () async {
      await writeNativeVersion(library, await record('fingerprint'));

      expect(await isNativeVersionCurrent(library, 'other'), isFalse);
    });

    test('a library without a version is not current', () async {
      expect(await readNativeVersion(library), isNull);
      expect(await isNativeVersionCurrent(library, 'fingerprint'), isFalse);
    });

    test('a library that changed since it was recorded is not current', () async {
      await writeNativeVersion(library, await record('fingerprint'));

      await library.writeAsBytes(const [1, 2, 3]);

      expect(await isNativeVersionCurrent(library, 'fingerprint'), isFalse);
    });

    test('an unreadable version leaves the library outdated', () async {
      await File('${library.path}.version').writeAsString('{"fingerprint": ');

      expect(await readNativeVersion(library), isNull);
      expect(await isNativeVersionCurrent(library, 'fingerprint'), isFalse);
    });

    test('refuses to record the version of an empty library', () async {
      await library.writeAsBytes(const []);

      expect(
        record('fingerprint'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('is missing or empty'),
          ),
        ),
      );
    });
  });

  group('native version manifest', () {
    const version = NativeVersion(
      fingerprint: 'fingerprint',
      easytier: '1649ec00135e12103e05bf543e0ed313d7e190f8',
      platform: 'linux',
      arch: 'x86_64',
      sha256: 'digest',
      builtAt: '2026-08-27T10:00:00.000Z',
    );

    test('lists the version of every published library', () {
      final manifest = NativeVersionManifest.fromJson(
        jsonDecode(
          jsonEncode(
            const NativeVersionManifest(
              generatedAt: '2026-08-27T10:00:00.000Z',
              assets: {'linux-x86_64-libeasytier_ffi.so': version},
            ).toJson(),
          ),
        ) as Map<String, Object?>,
      );

      expect(manifest.generatedAt, '2026-08-27T10:00:00.000Z');
      expect(
        manifest['linux-x86_64-libeasytier_ffi.so']?.sha256,
        'digest',
      );
      expect(manifest['windows-x64-easytier_ffi.dll'], isNull);
    });

    test('refuses a manifest without the libraries it describes', () {
      expect(
        () => NativeVersionManifest.fromJson(const {'assets': <String, Object?>{}}),
        throwsFormatException,
      );
      expect(
        () => NativeVersionManifest.fromJson(const {
          'generated_at': '2026-08-27T10:00:00.000Z',
          'assets': {
            'linux-x86_64-libeasytier_ffi.so': {'fingerprint': 'fingerprint'},
          },
        }),
        throwsFormatException,
      );
    });
  });
}

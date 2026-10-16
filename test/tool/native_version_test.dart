import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_version.dart';
import '../../tool/native_version.dart';

const String revision = '1649ec00135e12103e05bf543e0ed313d7e190f8';

void main() {
  late Directory packageRoot;

  setUp(() async {
    packageRoot = await Directory.systemTemp.createTemp('native_version_tool');
    await File('${packageRoot.path}/xmake.lua').writeAsString(
      'set_allowedarchs("windows|x64", "linux|x86_64")\n'
      'add_versions(easytier_version, "$revision")\n',
    );
  });

  tearDown(() => packageRoot.delete(recursive: true));

  /// Lays out an artifact the way `actions/download-artifact` leaves it.
  File artifact(String name, String binary) {
    final file = File('${packageRoot.path}/artifacts/$name/$binary')
      ..createSync(recursive: true);
    return file..writeAsBytesSync(utf8.encode('the $binary of $name'));
  }

  String output() => '${packageRoot.path}/natives.json';

  group('writeNativeVersionManifest', () {
    test('writes the version of every artifact it is given', () async {
      final linux = artifact('linux-x86_64-libeasytier_ffi.so', 'libeasytier_ffi.so');
      final windows = artifact('windows-x64-easytier_ffi.dll', 'easytier_ffi.dll');

      await writeNativeVersionManifest(packageRoot.uri, [
        output(),
        'linux/x86_64=${linux.path}',
        'windows/x64=${windows.path}',
      ]);

      final manifest = NativeVersionManifest.fromJson(
        jsonDecode(File(output()).readAsStringSync()) as Map<String, Object?>,
      );
      final sources = File('${packageRoot.path}/xmake.lua').readAsStringSync();
      expect(
        manifest['linux-x86_64-libeasytier_ffi.so']?.fingerprint,
        nativeFingerprint(platform: 'linux', arch: 'x86_64', xmakeLua: sources),
      );
      expect(
        manifest['windows-x64-easytier_ffi.dll']?.fingerprint,
        nativeFingerprint(platform: 'windows', arch: 'x64', xmakeLua: sources),
      );
      expect(
        manifest['linux-x86_64-libeasytier_ffi.so']?.sha256,
        await sha256OfFile(linux),
      );
      expect(manifest['linux-x86_64-libeasytier_ffi.so']?.easytier, revision);
    });

    test('refuses a target the sources do not build', () async {
      final library = artifact('linux-x86_64-libeasytier_ffi.so', 'libeasytier_ffi.so');

      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [
          output(),
          'linux/x86-64=${library.path}',
        ]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('does not build linux/x86-64'),
          ),
        ),
      );
    });

    test('refuses a library that is not in its asset directory', () async {
      final library = artifact('linux-arm64-libeasytier_ffi.so', 'libeasytier_ffi.so');

      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [
          output(),
          'linux/x86_64=${library.path}',
        ]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('has to be a directory named'),
          ),
        ),
      );
    });

    test('refuses arguments it cannot read', () async {
      final library = artifact('linux-x86_64-libeasytier_ffi.so', 'libeasytier_ffi.so');
      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [output(), 'linux/x86_64']),
        throwsFormatException,
      );
      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [
          output(),
          '= ${library.path}',
        ]),
        throwsFormatException,
      );
      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [output()]),
        throwsFormatException,
      );
    });

    test('refuses an artifact that is not there', () async {
      await expectLater(
        writeNativeVersionManifest(packageRoot.uri, [
          output(),
          'linux/x86_64=${packageRoot.path}/artifacts/'
              'linux-x86_64-libeasytier_ffi.so/libeasytier_ffi.so',
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('stampNativeLibrary', () {
    test('records what a library built by hand was built from', () async {
      final library = artifact('linux-x86_64-libeasytier_ffi.so', 'libeasytier_ffi.so');

      await stampNativeLibrary(packageRoot.uri, [
        'linux',
        'x86_64',
        library.path,
      ]);

      final fingerprint = nativeFingerprint(
        platform: 'linux',
        arch: 'x86_64',
        xmakeLua: File('${packageRoot.path}/xmake.lua').readAsStringSync(),
      );
      expect(await isNativeVersionCurrent(library, fingerprint), isTrue);
      expect((await readNativeVersion(library))?.easytier, revision);
    });

    test('refuses a target the sources do not build', () async {
      final library = artifact('linux-x86_64-libeasytier_ffi.so', 'libeasytier_ffi.so');

      await expectLater(
        stampNativeLibrary(packageRoot.uri, ['linux', 'arm64', library.path]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('does not build linux/arm64'),
          ),
        ),
      );
      expect(await readNativeVersion(library), isNull);
    });
  });
}

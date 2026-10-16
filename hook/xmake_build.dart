import 'dart:io';

import 'native_version.dart';

/// Builds the EasyTier library of [platform]/[arch] from the sources in
/// [packageRoot] with xmake, and records what it was built from next to it.
///
/// [library] is where the hook looks for a local build.
Future<Uri> buildLibraryWithXmake({
  required Uri packageRoot,
  required String platform,
  required String arch,
  required File library,
  required String fingerprint,
  required String easytier,
}) async {
  // Whatever is at [library] could not be used, and the version recorded below
  // claims the library came from the current sources. Removing it makes a run
  // that does not write one fail, instead of recording a library it did not
  // build.
  for (final stale in [library, File('${library.path}$versionSuffix')]) {
    if (await stale.exists()) await stale.delete();
  }

  final configureArgs = <String>[
    'f',
    '-p',
    platform,
    '-a',
    arch,
    '-m',
    'release',
    '-y',
  ];
  if (platform == 'linux' && arch == 'arm64') {
    configureArgs.add('--cross=aarch64-linux-gnu-');
  }
  if (platform == 'android') {
    final ndk = Platform.environment['ANDROID_NDK_HOME'];
    if (ndk != null) configureArgs.add('--ndk=$ndk');
  }
  for (final args in [configureArgs, <String>['-r']]) {
    final result = await Process.run(
      'xmake',
      args,
      workingDirectory: packageRoot.toFilePath(),
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'xmake',
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }
  if (!await library.exists() || await library.length() == 0) {
    throw StateError('xmake did not produce ${library.path}');
  }
  await writeNativeVersion(
    library,
    await nativeVersionOf(
      library: library,
      fingerprint: fingerprint,
      easytier: easytier,
      platform: platform,
      arch: arch,
    ),
  );
  return library.uri;
}

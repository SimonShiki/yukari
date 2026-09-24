import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    final targetArchitecture = input.config.code.targetArchitecture;
    final (platform, arch, library) = _target(targetOS, targetArchitecture);
    final packageRoot = input.packageRoot;
    final localLibrary = File.fromUri(
      packageRoot.resolve('build/$platform/$arch/release/$library'),
    );
    output.dependencies.add(packageRoot.resolve('third_party/easytier/ffi.h'));

    final Uri libraryUri;
    if (await localLibrary.exists() && await localLibrary.length() > 0) {
      libraryUri = localLibrary.uri;
      output.dependencies.add(libraryUri);
    } else {
      final assetName = '$platform-$arch-$library';
      final downloaded = File.fromUri(input.outputDirectory.resolve(assetName));
      Object? downloadError;
      if (!await downloaded.exists() || await downloaded.length() == 0) {
        try {
          final url = Uri.parse(
            'https://github.com/SimonShiki/yukari/releases/download/natives/$assetName',
          );
          await _download(url, downloaded);
        } catch (error) {
          downloadError = error;
        }
      }

      if (downloadError == null) {
        libraryUri = downloaded.uri;
      } else {
        try {
          libraryUri = await _buildLocally(
            packageRoot,
            platform,
            arch,
            localLibrary,
          );
          output.dependencies.add(libraryUri);
        } catch (buildError) {
          throw StateError(
            'EasyTier $platform/$arch: download failed: $downloadError; '
            'local build failed: $buildError',
          );
        }
      }
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'bindings/generated/easytier.g.dart',
        linkMode: DynamicLoadingBundled(),
        file: libraryUri,
      ),
    );
    if (targetOS == OS.windows) {
      for (final runtimeLibrary in await _windowsRuntimeLibraries(
        input.outputDirectory,
        localLibrary.parent,
      )) {
        output.assets.code.add(
          CodeAsset(
            package: input.packageName,
            name: 'bindings/${runtimeLibrary.pathSegments.last}',
            linkMode: DynamicLoadingBundled(),
            file: runtimeLibrary,
          ),
        );
      }
    }
  });
}

Future<List<Uri>> _windowsRuntimeLibraries(
  Uri outputDirectory,
  Directory localDirectory,
) async {
  const revision = '7223677264f1d99f55b9c30888d09ccbf55671c3';
  const names = ['Packet.dll', 'wintun.dll', 'WinDivert64.sys'];
  final result = <Uri>[];
  for (final name in names) {
    final localFile = File.fromUri(localDirectory.uri.resolve(name));
    if (await localFile.exists() && await localFile.length() > 0) {
      result.add(localFile.uri);
      continue;
    }
    final file = File.fromUri(outputDirectory.resolve(name));
    if (!await file.exists() || await file.length() == 0) {
      await _download(
        Uri.parse(
          'https://raw.githubusercontent.com/EasyTier/EasyTier/'
          '$revision/easytier/third_party/x86_64/$name',
        ),
        file,
      );
    }
    result.add(file.uri);
  }
  return result;
}

(String, String, String) _target(OS os, Architecture architecture) {
  if (os == OS.windows && architecture == Architecture.x64) {
    return ('windows', 'x64', 'easytier_ffi.dll');
  }
  if (os == OS.linux && architecture == Architecture.x64) {
    return ('linux', 'x86_64', 'libeasytier_ffi.so');
  }
  if (os == OS.linux && architecture == Architecture.arm64) {
    return ('linux', 'arm64', 'libeasytier_ffi.so');
  }
  if (os == OS.android && architecture == Architecture.arm64) {
    return ('android', 'arm64-v8a', 'libeasytier_ffi.so');
  }
  if (os == OS.android && architecture == Architecture.x64) {
    return ('android', 'x86_64', 'libeasytier_ffi.so');
  }
  throw UnsupportedError('Unsupported EasyTier target: $os/$architecture');
}

Future<void> _download(Uri url, File destination) async {
  final client = HttpClient();
  final partial = File('${destination.path}.download');
  try {
    if (await destination.exists()) await destination.delete();
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    await response.pipe(partial.openWrite());
    if (await partial.length() == 0) {
      throw StateError('Empty EasyTier release asset: $url');
    }
    await partial.rename(destination.path);
  } finally {
    client.close(force: true);
    if (await partial.exists()) await partial.delete();
  }
}

Future<Uri> _buildLocally(
  Uri packageRoot,
  String platform,
  String arch,
  File library,
) async {
  final directory = packageRoot.toFilePath();
  final configureArgs = [
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
  for (final arguments in [
    configureArgs,
    ['-r'],
  ]) {
    final result = await Process.run(
      'xmake',
      arguments,
      workingDirectory: directory,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'xmake',
        arguments,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }
  if (!await library.exists() || await library.length() == 0) {
    throw StateError('xmake did not produce ${library.path}');
  }
  return library.uri;
}

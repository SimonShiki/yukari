import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../hook/native_version.dart';

/// Writes the version information of the prebuilt EasyTier libraries.
///
/// `manifest` writes the `natives.json` that
/// `.github/workflows/build-native-libraries.yml` publishes next to the
/// libraries, which is how `hook/build.dart` tells whether a published library
/// was built from the sources of a checkout.
///
/// `stamp` records the version of a library built by hand, so that the hook
/// keeps using it instead of downloading or rebuilding one.
///
/// Usage:
/// ```shell
/// dart run tool/native_version.dart manifest natives.json linux/x86_64=<library>...
/// dart run tool/native_version.dart stamp linux x86_64 <library>
/// ```
Future<void> main(List<String> args) async {
  final packageRoot = Platform.script.resolve('../');
  try {
    switch (args.isEmpty ? '' : args.first) {
      case 'manifest':
        await writeNativeVersionManifest(packageRoot, args.skip(1).toList());
      case 'stamp':
        await stampNativeLibrary(packageRoot, args.skip(1).toList());
      default:
        throw const FormatException('expected "manifest" or "stamp"');
    }
  } on Object catch (error) {
    stderr.writeln('native_version: $error');
    exitCode = 1;
  }
}

/// Writes the version of every `<platform>/<arch>=<library>` argument into the
/// `<output.json>` first argument, keyed by release asset name.
///
/// The library of an argument has to sit in a directory named after the release
/// asset it becomes, as `actions/download-artifact` lays the artifacts out, so
/// that a library of another target cannot be published under this one's
/// fingerprint. The targets are checked against `xmake.lua` of [packageRoot], so
/// a typo fails here instead of publishing a manifest nothing can use.
Future<void> writeNativeVersionManifest(
  Uri packageRoot,
  List<String> arguments,
) async {
  final targets = arguments.skip(1).toList();
  if (arguments.isEmpty || targets.isEmpty) {
    throw const FormatException(
      'usage: manifest <output.json> <platform>/<arch>=<library>...',
    );
  }
  final xmakeLua = await _readXmakeLua(packageRoot);
  final easytier = easyTierRevision(xmakeLua);
  final assets = <String, NativeVersion>{};
  for (final target in targets) {
    final (platform, arch, library) = _parseTarget(target);
    _checkTarget(xmakeLua, platform, arch);
    final assetName = nativeAssetName(
      platform: platform,
      arch: arch,
      library: path.basename(library.path),
    );
    if (path.basename(library.parent.path) != assetName) {
      throw FormatException(
        'the artifact of $platform/$arch has to be a directory named '
        '$assetName holding ${path.basename(library.path)}, got ${library.path}',
      );
    }
    assets[assetName] = await nativeVersionOf(
      library: library,
      fingerprint: nativeFingerprint(
        platform: platform,
        arch: arch,
        xmakeLua: xmakeLua,
      ),
      easytier: easytier,
      platform: platform,
      arch: arch,
    );
  }

  final output = File(arguments.first);
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(NativeVersionManifest(
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      assets: assets,
    ).toJson())}\n',
  );
  stdout.writeln('${output.path} (EasyTier $easytier):');
  for (final entry in assets.entries) {
    stdout.writeln('  ${entry.key} ${entry.value.fingerprint}');
  }
}

/// Records the version of a library built by hand, so that the hook keeps using
/// it while it matches the sources of [packageRoot].
Future<void> stampNativeLibrary(
  Uri packageRoot,
  List<String> arguments,
) async {
  if (arguments.length != 3) {
    throw const FormatException('usage: stamp <platform> <arch> <library>');
  }
  final [platform, arch, path] = arguments;
  final library = File(path);
  final xmakeLua = await _readXmakeLua(packageRoot);
  _checkTarget(xmakeLua, platform, arch);
  final version = await nativeVersionOf(
    library: library,
    fingerprint: nativeFingerprint(
      platform: platform,
      arch: arch,
      xmakeLua: xmakeLua,
    ),
    easytier: easyTierRevision(xmakeLua),
    platform: platform,
    arch: arch,
  );
  await writeNativeVersion(library, version);
  stdout.writeln('${library.path} ${version.fingerprint}');
}

/// Splits a `<platform>/<arch>=<library>` argument.
(String, String, File) _parseTarget(String argument) {
  final separator = argument.indexOf('=');
  final target = separator < 0 ? argument : argument.substring(0, separator);
  final path = separator < 0 ? '' : argument.substring(separator + 1);
  final parts = target.split('/');
  if (parts.length != 2 || parts.any((part) => part.isEmpty) || path.isEmpty) {
    throw FormatException(
      'expected <platform>/<arch>=<library>, got "$argument"',
    );
  }
  return (parts[0], parts[1], File(path));
}

/// Refuses a target that [xmakeLua] does not build, whose libraries no
/// fingerprint of this checkout can match.
void _checkTarget(String xmakeLua, String platform, String arch) {
  if (!xmakeLua.contains('"$platform|$arch"')) {
    throw FormatException('xmake.lua does not build $platform/$arch');
  }
}

Future<String> _readXmakeLua(Uri packageRoot) =>
    File.fromUri(packageRoot.resolve('xmake.lua')).readAsString();

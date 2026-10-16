import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'native_library.dart';
import 'native_version.dart';
import 'prebuilt_assets.dart';
import 'xmake_build.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final target = _target(
      input.config.code.targetOS,
      input.config.code.targetArchitecture,
    );
    if (target == null) return;
    final (platform, arch, libraryName) = target;

    final packageRoot = input.packageRoot;
    // A library is identified by the fingerprint of the sources that built it,
    // and xmake.lua is where those sources are pinned. Declaring it as a
    // dependency is what reruns the hook when it changes.
    final sources = packageRoot.resolve('xmake.lua');
    output.dependencies.add(sources);
    output.dependencies.add(packageRoot.resolve('third_party/easytier/ffi.h'));

    final xmakeLua = await File.fromUri(sources).readAsString();
    final fingerprint = nativeFingerprint(
      platform: platform,
      arch: arch,
      xmakeLua: xmakeLua,
    );
    final easytier = easyTierRevision(xmakeLua);
    final localLibrary = File.fromUri(
      packageRoot.resolve('build/$platform/$arch/release/$libraryName'),
    );

    final libraryUri = await resolveNativeLibrary(
      localLibrary: localLibrary,
      fingerprint: fingerprint,
      platform: platform,
      arch: arch,
      fetchPrebuilt: () => fetchPrebuiltLibrary(
        assetName: nativeAssetName(
          platform: platform,
          arch: arch,
          library: libraryName,
        ),
        fingerprint: fingerprint,
        cacheDirectory: Directory.fromUri(input.outputDirectory),
      ),
      buildLocally: () => buildLibraryWithXmake(
        packageRoot: packageRoot,
        platform: platform,
        arch: arch,
        library: localLibrary,
        fingerprint: fingerprint,
        easytier: easytier,
      ),
    );
    output.dependencies.add(libraryUri);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'bindings/generated/easytier.g.dart',
        linkMode: DynamicLoadingBundled(),
        file: libraryUri,
      ),
    );
    if (input.config.code.targetOS == OS.windows) {
      // The runtime libraries of a local build belong to that build; a
      // downloaded library gets the ones published for its revision.
      for (final runtimeLibrary in await windowsRuntimeLibrariesFor(
        localDirectory: libraryUri == localLibrary.uri
            ? localLibrary.parent
            : null,
        cacheDirectory: Directory.fromUri(input.outputDirectory),
        revision: easytier,
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

(String, String, String)? _target(OS os, Architecture architecture) {
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
  // EasyTier ships no 32-bit ARM Android build, but Flutter still runs this hook
  // for `android/arm` because that is one of its default Android target platforms,
  // no matter which ABIs the APK keeps. Bundle nothing for such a target.
  if (os == OS.android && architecture == Architecture.arm) return null;
  throw UnsupportedError('Unsupported EasyTier target: $os/$architecture');
}

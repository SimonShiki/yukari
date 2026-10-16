import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The suffix of the file that carries a library's version: `<library>.version`.
const String versionSuffix = '.version';

/// The SHA-1 fingerprint of the sources that build the EasyTier library for
/// `platform`/`arch`.
///
/// `xmake.lua` pins the EasyTier revision, the Rust toolchain, the compiler and
/// linker flags and the Android API level, which is what the library is built
/// from. Hashing it instead of copying it around keeps the version files small,
/// and lets a library carry the fingerprint of its sources.
///
/// Line endings are normalised, because a Windows checkout may have CRLF in
/// `xmake.lua` while the published manifest was written from LF, and both have
/// to name the same sources. What the toolchain of the machine adds (such as a
/// cross compiler or an NDK) is not part of the fingerprint: it decides how the
/// library is built, not which EasyTier it carries.
String nativeFingerprint({
  required String platform,
  required String arch,
  required String xmakeLua,
}) {
  final sources = xmakeLua.replaceAll('\r\n', '\n');
  return sha1
      .convert(utf8.encode('easytier-ffi $platform/$arch\n$sources'))
      .toString();
}

final RegExp _pinnedRevision = RegExp(
  r'add_versions\(\s*easytier_version\s*,\s*"([0-9a-f]{40})"\s*\)',
);

/// The EasyTier revision pinned by `xmake.lua`.
///
/// The Windows runtime libraries are fetched from that revision, so sources
/// without it cannot be built from. Throws a [FormatException] instead of
/// guessing, as a wrong revision would bundle libraries of another version.
String easyTierRevision(String xmakeLua) {
  final revision = _pinnedRevision.firstMatch(xmakeLua)?.group(1);
  if (revision == null) {
    throw const FormatException(
      'xmake.lua must pin the EasyTier revision with '
      'add_versions(easytier_version, "<sha1>")',
    );
  }
  return revision;
}

/// The release asset name of the prebuilt library of a target, which is also
/// how the version manifest is keyed.
String nativeAssetName({
  required String platform,
  required String arch,
  required String library,
}) =>
    '$platform-$arch-$library';

/// What a library file was built from.
class NativeVersion {
  const NativeVersion({
    required this.fingerprint,
    required this.easytier,
    required this.platform,
    required this.arch,
    required this.sha256,
    required this.builtAt,
  });

  factory NativeVersion.fromJson(Map<String, Object?> json) {
    String read(String name) {
      final value = json[name];
      if (value is! String || value.isEmpty) {
        throw FormatException('native version has no "$name"');
      }
      return value;
    }

    return NativeVersion(
      fingerprint: read('fingerprint'),
      easytier: read('easytier'),
      platform: read('platform'),
      arch: read('arch'),
      sha256: read('sha256'),
      builtAt: read('built_at'),
    );
  }

  /// The fingerprint of the sources the library was built from.
  final String fingerprint;

  /// The EasyTier revision the library was built from.
  final String easytier;

  final String platform;
  final String arch;

  /// The SHA-256 of the library file, so that a replaced or truncated copy of
  /// the same path is not mistaken for the library this describes.
  final String sha256;

  /// When the library was built, for whoever reads the file.
  final String builtAt;

  Map<String, Object?> toJson() => {
        'fingerprint': fingerprint,
        'easytier': easytier,
        'platform': platform,
        'arch': arch,
        'sha256': sha256,
        'built_at': builtAt,
      };
}

/// The version of every prebuilt library of the `natives` release, published as
/// `natives.json` next to the libraries.
class NativeVersionManifest {
  const NativeVersionManifest({required this.generatedAt, required this.assets});

  factory NativeVersionManifest.fromJson(Map<String, Object?> json) {
    final generatedAt = json['generated_at'];
    final assets = json['assets'];
    if (generatedAt is! String || assets is! Map<String, Object?>) {
      throw const FormatException('malformed native version manifest');
    }
    final versions = <String, NativeVersion>{};
    for (final entry in assets.entries) {
      final value = entry.value;
      if (value is Map<String, Object?>) {
        versions[entry.key] = NativeVersion.fromJson(value);
      }
    }
    return NativeVersionManifest(generatedAt: generatedAt, assets: versions);
  }

  /// When the manifest was written.
  final String generatedAt;

  /// The version of each published library, keyed by release asset name.
  final Map<String, NativeVersion> assets;

  /// The version published as [assetName], or null when there is none.
  NativeVersion? operator [](String assetName) => assets[assetName];

  Map<String, Object?> toJson() => {
        'generated_at': generatedAt,
        'assets': {
          for (final entry in assets.entries) entry.key: entry.value.toJson(),
        },
      };
}

/// The SHA-256 of [file].
Future<String> sha256OfFile(File file) async =>
    sha256.convert(await file.readAsBytes()).toString();

/// Reads the version stored next to [library], or null when there is none or it
/// cannot be read.
///
/// An unknown library is treated as outdated, so an unreadable version file
/// costs a rebuild rather than risking a stale library.
Future<NativeVersion?> readNativeVersion(File library) async {
  try {
    final json = jsonDecode(
      await File('${library.path}$versionSuffix').readAsString(),
    );
    if (json is! Map<String, Object?>) {
      throw const FormatException('native version is not a JSON object');
    }
    return NativeVersion.fromJson(json);
  } on Object {
    return null;
  }
}

/// Whether [library] is a build of the sources [fingerprint] describes.
Future<bool> isNativeVersionCurrent(File library, String fingerprint) async {
  final version = await readNativeVersion(library);
  if (version == null || version.fingerprint != fingerprint) return false;
  if (!await library.exists() || await library.length() == 0) return false;
  return version.sha256 == await sha256OfFile(library);
}

/// The version to record for [library].
Future<NativeVersion> nativeVersionOf({
  required File library,
  required String fingerprint,
  required String easytier,
  required String platform,
  required String arch,
  DateTime? builtAt,
}) async {
  if (!await library.exists() || await library.length() == 0) {
    throw StateError('${library.path} is missing or empty');
  }
  return NativeVersion(
    fingerprint: fingerprint,
    easytier: easytier,
    platform: platform,
    arch: arch,
    sha256: await sha256OfFile(library),
    builtAt: (builtAt ?? DateTime.now()).toUtc().toIso8601String(),
  );
}

/// Writes the version of [library] next to it, as `<library>.version`.
Future<void> writeNativeVersion(File library, NativeVersion version) =>
    File('${library.path}$versionSuffix').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(version.toJson())}\n',
    );

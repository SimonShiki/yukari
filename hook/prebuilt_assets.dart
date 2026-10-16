import 'dart:convert';
import 'dart:io';

import 'native_version.dart';

/// The version manifest of the prebuilt EasyTier libraries, which sits next to
/// them in the `natives` release. See `.github/workflows/build-native-libraries.yml`.
final Uri nativeVersionManifestUrl = Uri.parse(
  'https://github.com/SimonShiki/yukari/releases/download/natives/natives.json',
);

/// The Windows runtime libraries EasyTier loads next to `easytier_ffi.dll`.
const List<String> windowsRuntimeLibraries = <String>[
  'Packet.dll',
  'wintun.dll',
  'WinDivert64.sys',
];

/// Returns the prebuilt library published as [assetName] when it was built from
/// [fingerprint], downloading it into [cacheDirectory] if needed, or null when
/// the release publishes no library for those sources.
///
/// [manifestUrl] locates the release; its libraries are expected next to the
/// manifest. A cached library that still matches the manifest is returned
/// without a single request.
Future<Uri?> fetchPrebuiltLibrary({
  required String assetName,
  required String fingerprint,
  required Directory cacheDirectory,
  Uri? manifestUrl,
}) async {
  final release = manifestUrl ?? nativeVersionManifestUrl;
  final library = File.fromUri(cacheDirectory.uri.resolve(assetName));
  if (await isNativeVersionCurrent(library, fingerprint)) return library.uri;

  final published = (await fetchNativeVersionManifest(release))[assetName];
  if (published == null || published.fingerprint != fingerprint) return null;

  if (!await library.exists() ||
      await sha256OfFile(library) != published.sha256) {
    await _download(release.resolve(assetName), library);
    if (await sha256OfFile(library) != published.sha256) {
      await library.delete();
      throw StateError(
        '$assetName does not match the sha256 published for it',
      );
    }
  }
  await writeNativeVersion(library, published);
  return library.uri;
}

/// Downloads the version manifest of the release at [url].
Future<NativeVersionManifest> fetchNativeVersionManifest(Uri url) async {
  final json = jsonDecode(utf8.decode(await _read(url)));
  if (json is! Map<String, Object?>) {
    throw FormatException('$url does not hold a JSON object');
  }
  return NativeVersionManifest.fromJson(json);
}

/// Returns the Windows runtime libraries of [revision], taking the ones a local
/// build put into [localDirectory] and downloading the rest.
///
/// [localDirectory] is null when the bundled EasyTier library was not built
/// locally, whose runtime libraries belong to another revision.
///
/// Downloads are cached per revision, as these files come from EasyTier rather
/// than from this checkout: a new revision ships new files.
Future<List<Uri>> windowsRuntimeLibrariesFor({
  required Directory? localDirectory,
  required Directory cacheDirectory,
  required String revision,
}) async {
  final libraries = <Uri>[];
  for (final name in windowsRuntimeLibraries) {
    final local = localDirectory == null
        ? null
        : File.fromUri(localDirectory.uri.resolve(name));
    if (local != null && await local.exists() && await local.length() > 0) {
      libraries.add(local.uri);
      continue;
    }
    final cached = File.fromUri(cacheDirectory.uri.resolve('$revision/$name'));
    if (!await cached.exists() || await cached.length() == 0) {
      await _download(
        Uri.parse(
          'https://raw.githubusercontent.com/EasyTier/EasyTier/$revision/'
          'easytier/third_party/x86_64/$name',
        ),
        cached,
      );
    }
    libraries.add(cached.uri);
  }
  return libraries;
}

/// Reads [url] completely.
Future<List<int>> _read(Uri url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return await response.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
  } finally {
    client.close(force: true);
  }
}

/// Downloads [url] into [destination], which is only replaced once the whole
/// download arrived.
Future<void> _download(Uri url, File destination) async {
  final client = HttpClient();
  final partial = File('${destination.path}.download');
  try {
    await destination.parent.create(recursive: true);
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    await response.pipe(partial.openWrite());
    if (await partial.length() == 0) {
      throw StateError('empty download from $url');
    }
    if (await destination.exists()) await destination.delete();
    await partial.rename(destination.path);
  } finally {
    client.close(force: true);
    if (await partial.exists()) await partial.delete();
  }
}

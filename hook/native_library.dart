import 'dart:io';

import 'native_version.dart';

/// Picks the EasyTier library to bundle for one target.
///
/// A local xmake build is used while it was built from the current sources, so a
/// library left over from older sources is never bundled; it is left where it is
/// until a local build replaces it. When the sources are the ones the `natives`
/// release was built from, the published prebuilt library is downloaded rather
/// than compiling EasyTier locally. Building locally is the last resort, so a
/// checkout stays buildable while nothing is published for its sources.
///
/// Throws a [StateError] naming every source that failed when none works.
Future<Uri> resolveNativeLibrary({
  required File localLibrary,
  required String fingerprint,
  required String platform,
  required String arch,
  required Future<Uri?> Function() fetchPrebuilt,
  required Future<Uri> Function() buildLocally,
}) async {
  if (await isNativeVersionCurrent(localLibrary, fingerprint)) {
    return localLibrary.uri;
  }

  final problems = <String>[];
  try {
    final prebuilt = await fetchPrebuilt();
    if (prebuilt != null) return prebuilt;
    problems.add(
      'no prebuilt library for $platform/$arch built from the current sources',
    );
  } on Object catch (error) {
    problems.add('prebuilt library: $error');
  }

  try {
    return await buildLocally();
  } on Object catch (error) {
    problems.add('local build: $error');
  }
  throw StateError('EasyTier $platform/$arch: ${problems.join('; ')}');
}

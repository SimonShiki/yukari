/// The GitHub release that contains the service module for this app build.
///
/// The release workflow embeds its stable tag or an immutable canary build tag.
/// Local builds must specify a tag with `--dart-define` to install a module.
const serviceModuleReleaseTag = String.fromEnvironment(
  'SERVICE_MODULE_RELEASE_TAG',
);

/// Returns a service-module asset from the release tagged [releaseTag].
Uri serviceModuleReleaseAsset(String releaseTag, String assetName) {
  if (releaseTag.isEmpty) {
    throw StateError(
      'This build has no service module release. '
      'Build with --dart-define=SERVICE_MODULE_RELEASE_TAG=<release tag>.',
    );
  }
  return Uri.https('github.com', '').replace(
    pathSegments: [
      'SimonShiki',
      'yukari',
      'releases',
      'download',
      releaseTag,
      assetName,
    ],
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/system/module_service_control.dart';
import 'package:yukari/backend/system/service_module_release.dart';

void main() {
  test('installer uses only the release embedded in this build', () async {
    if (serviceModuleReleaseTag.isEmpty) {
      await expectLater(
        ModuleServiceControl(dataDir: '/unused').install(),
        throwsStateError,
      );
    } else {
      expect(
        ModuleServiceControl.release.pathSegments[4],
        serviceModuleReleaseTag,
      );
      expect(
        ModuleServiceControl.releaseSignature.pathSegments[4],
        serviceModuleReleaseTag,
      );
      expect(
        ModuleServiceControl.releaseSignature.pathSegments.last,
        'yukari-service-module.zip.sig',
      );
    }
  });

  for (final tag in ['v1.2.3', 'canary-123456-1']) {
    test('uses the $tag release for the module and its signature', () {
      final module = serviceModuleReleaseAsset(
        tag,
        'yukari-service-module.zip',
      );
      final signature = module.replace(path: '${module.path}.sig');

      expect(
        module,
        Uri.https(
          'github.com',
          '/SimonShiki/yukari/releases/download/$tag/'
              'yukari-service-module.zip',
        ),
      );
      expect(
        signature,
        Uri.https(
          'github.com',
          '/SimonShiki/yukari/releases/download/$tag/'
              'yukari-service-module.zip.sig',
        ),
      );
    });
  }

  test('older canaries keep a different module URL from newer canaries', () {
    expect(
      serviceModuleReleaseAsset('canary-123456-1', 'yukari-service-module.zip'),
      isNot(
        serviceModuleReleaseAsset(
          'canary-123457-1',
          'yukari-service-module.zip',
        ),
      ),
    );
  });

  test('refuses module installation without an explicit release', () {
    expect(
      () => serviceModuleReleaseAsset('', 'yukari-service-module.zip'),
      throwsStateError,
    );
  });

  test('keeps the release tag in a single URL segment', () {
    final module = serviceModuleReleaseAsset(
      'releases/v1.2.3',
      'yukari-service-module.zip',
    );
    expect(module.pathSegments[4], 'releases/v1.2.3');
    expect(module.toString(), contains('releases%2Fv1.2.3'));
  });
}

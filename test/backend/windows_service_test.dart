@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/backend/system/windows_service.dart';

void main() {
  late Directory directory;
  late Directory app;
  late WindowsService service;
  late String bundled;

  /// Writes the layout the app ships: `bin/yukari-service.exe` and the `lib`
  /// directory beside it, which holds the native libraries the service loads.
  Future<void> bundleApp({
    String library = 'windows-x64-easytier_ffi.dll',
  }) async {
    final bin = await Directory(p.join(app.path, 'bin')).create();
    await File(p.join(bin.path, 'yukari-service.exe')).writeAsString('service');
    final lib = await Directory(p.join(app.path, 'lib')).create();
    await File(p.join(lib.path, library)).writeAsString('library');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yukari_service_bundle');
    addTearDown(() => directory.delete(recursive: true));
    app = await Directory(p.join(directory.path, 'app')).create();
    service = WindowsService(root: p.join(directory.path, 'service'));
    bundled = p.join(app.path, 'bin', 'yukari-service.exe');
    await bundleApp();
  });

  test('keeps the copy where the people using the app cannot write it', () {
    // Program Files gives users read and execute alone. A copy anywhere the
    // user can replace would hand them the service's LocalSystem privileges,
    // so moving this is a decision rather than an edit.
    final programFiles =
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files';

    expect(
      WindowsService.defaultRoot,
      p.join(programFiles, 'Yukari', 'service'),
    );
  });

  test('runs the service from a copy of the app bundle', () async {
    final staged = await service.stage(bundled);

    expect(staged, p.join(service.root, 'bin', 'yukari-service.exe'));
    expect(await File(staged).readAsString(), 'service');
    expect(
      await File(
        p.join(service.root, 'lib', 'windows-x64-easytier_ffi.dll'),
      ).readAsString(),
      'library',
    );
  });

  test('replaces the copy, dropping the older bundle files', () async {
    await service.stage(bundled);
    await File(p.join(service.root, 'lib', 'stale.dll')).writeAsString('stale');

    await service.stage(bundled);

    expect(
      await File(p.join(service.root, 'lib', 'stale.dll')).exists(),
      isFalse,
    );
    expect(
      await File(
        p.join(service.root, 'lib', 'windows-x64-easytier_ffi.dll'),
      ).exists(),
      isTrue,
    );
  });

  test('removes the copy, and is fine when there is none', () async {
    await service.stage(bundled);

    await service.removeBundle();
    await service.removeBundle();

    expect(await Directory(service.root).exists(), isFalse);
  });
}

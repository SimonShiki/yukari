@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari_core/backend/ipc/ipc_endpoint.dart';
import 'package:yukari_core/backend/security_windows.dart';
import 'package:yukari_core/backend/system/windows_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yukari_security');
    addTearDown(() => directory.delete(recursive: true));
  });

  test('reads the SID of the user running the app', () {
    expect(currentUserSid(), matches(sidPattern));
  });

  test('the service records its endpoint outside the data directory', () {
    expect(
      IpcEndpoint.file(directory.path),
      p.join(WindowsService.runDirectory, IpcEndpoint.tokenFile),
    );
  });

  test('a restricted file lets its reader read, and replaces any file', () {
    final path = p.join(directory.path, 'service.json');
    File(path).writeAsStringSync('old');

    writeRestrictedFile(path, '{"port":1}', currentUserSid()!);

    expect(File(path).readAsStringSync(), '{"port":1}');
    final acl = Process.runSync('icacls', [path]).stdout as String;
    expect(acl, isNot(contains('Everyone')));
    expect(acl, isNot(contains('BUILTIN\\Users')));
  });

  test('a restricted file refuses readers that are not SIDs', () {
    expect(
      () => writeRestrictedFile(
        p.join(directory.path, 'x'),
        '',
        'S-1-5-32-544)(A;;FA;;;WD',
      ),
      throwsArgumentError,
    );
  });
}

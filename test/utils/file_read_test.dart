import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/utils/file_read.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('yukari_file_read_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('readFileAtPath reads bytes of a regular file', () async {
    final file = File(p.join(tempDir.path, 'config.toml'))
      ..writeAsStringSync('network_name = "alpha"\n');

    final bytes = await readFileAtPath(file.path, maxBytes: 1024);

    expect(bytes, file.readAsBytesSync());
  });

  test('readFileAtPath rejects files larger than maxBytes', () async {
    final file = File(p.join(tempDir.path, 'large.toml'))
      ..writeAsBytesSync(List<int>.filled(65, 65));

    await expectLater(
      readFileAtPath(file.path, maxBytes: 64),
      throwsA(isA<FileTooLargeException>()),
    );
  });

  test('readFileAtPath rejects directories and missing files', () async {
    final dir = Directory(p.join(tempDir.path, 'folder'))..createSync();
    final missing = p.join(tempDir.path, 'missing.toml');

    await expectLater(
      readFileAtPath(dir.path, maxBytes: 1024),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      readFileAtPath(missing, maxBytes: 1024),
      throwsA(isA<FileSystemException>()),
    );
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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

  test('readFileAtPath reads bytes up to maxBytes', () async {
    final file = File(p.join(tempDir.path, 'config.toml'))
      ..writeAsBytesSync(List<int>.filled(64, 65));

    final bytes = await readFileAtPath(file.path, maxBytes: 64);

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

  test('readPickedFile reads bytes up to maxBytes', () async {
    final payload = Uint8List.fromList(List<int>.filled(64, 66));
    final file = _FakePlatformFile(
      name: 'exact.toml',
      knownLength: payload.length,
      chunks: [payload],
    );

    final bytes = await readPickedFile(file, maxBytes: 64);

    expect(bytes, payload);
    expect(file.streamOpened, isTrue);
  });

  test(
    'readPickedFile rejects oversized lengthSync without opening stream',
    () async {
      final file = _FakePlatformFile(
        name: 'huge.toml',
        knownLength: 65,
        chunks: [Uint8List(65)],
      );

      await expectLater(
        readPickedFile(file, maxBytes: 64),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(file.streamOpened, isFalse);
    },
  );

  test('readPickedFile turns sync throws into a rejected Future', () async {
    final file = _FakePlatformFile(
      name: 'broken.toml',
      onLengthSync: () => throw const FileSystemException('denied'),
    );

    final future = readPickedFile(file, maxBytes: 64);

    await expectLater(future, throwsA(isA<FileSystemException>()));
    expect(file.streamOpened, isFalse);
  });

  test(
    'readPickedFile rejects streaming overflow when lengthSync is null',
    () async {
      final file = _FakePlatformFile(
        name: 'streamed.toml',
        knownLength: null,
        chunks: [Uint8List(40), Uint8List(25)],
      );

      await expectLater(
        readPickedFile(file, maxBytes: 64),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(file.streamOpened, isTrue);
    },
  );
}

final class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile({
    required this.name,
    this.knownLength,
    this.chunks = const [],
    this.onLengthSync,
  });

  @override
  final String name;
  final int? knownLength;
  final List<Uint8List> chunks;
  final int? Function()? onLengthSync;
  bool streamOpened = false;

  @override
  Uri get uri => Uri.file('/tmp/$name');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => onLengthSync != null ? onLengthSync!() : knownLength;

  @override
  Future<int?> length() async => lengthSync();

  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList([for (final chunk in chunks) ...chunk]);

  @override
  Stream<Uint8List> readAsByteStream() {
    streamOpened = true;
    return Stream.fromIterable(chunks);
  }
}

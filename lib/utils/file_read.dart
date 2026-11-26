import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// A picked file larger than its reader accepts.
final class FileTooLargeException implements Exception {
  const FileTooLargeException(this.name, this.maxBytes);

  final String name;
  final int maxBytes;

  @override
  String toString() => '$name is larger than ${maxBytes ~/ 1024} KiB';
}

/// The bytes of the picked [file], refusing one over [maxBytes].
///
/// The user picks any file the platform offers, so its size is checked
/// before anything is read, and again while streaming for a platform that
/// does not report it: a huge file never sits in memory whole.
Future<Uint8List> readPickedFile(
  PlatformFile file, {
  required int maxBytes,
}) => _readBoundedBytes(
  file.readAsByteStream(),
  name: file.name,
  maxBytes: maxBytes,
  knownLength: file.lengthSync(),
);

/// The bytes of the regular file at [path], refusing non-files or files over
/// [maxBytes].
Future<Uint8List> readFileAtPath(String path, {required int maxBytes}) async {
  final file = File(path);
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file) {
    throw FileSystemException('Not a regular file', path);
  }
  return _readBoundedBytes(
    file.openRead(),
    name: p.basename(path),
    maxBytes: maxBytes,
    knownLength: stat.size,
  );
}

Future<Uint8List> _readBoundedBytes(
  Stream<List<int>> stream, {
  required String name,
  required int maxBytes,
  int? knownLength,
}) async {
  if ((knownLength ?? 0) > maxBytes) {
    throw FileTooLargeException(name, maxBytes);
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > maxBytes) {
      throw FileTooLargeException(name, maxBytes);
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

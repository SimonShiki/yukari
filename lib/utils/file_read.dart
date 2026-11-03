import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

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
}) async {
  if ((file.lengthSync() ?? 0) > maxBytes) {
    throw FileTooLargeException(file.name, maxBytes);
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.readAsByteStream()) {
    if (bytes.length + chunk.length > maxBytes) {
      throw FileTooLargeException(file.name, maxBytes);
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

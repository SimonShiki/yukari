import 'dart:convert';
import 'dart:io';

import 'private_file.dart';

/// Replaces [file] with [value] encoded as pretty JSON, atomically: a reader
/// sees either the old or the new content, never a half-written file.
///
/// The file holds secrets, so on POSIX only its owner may read it; on Windows
/// the per-user data directory's access list already keeps others out.
///
/// Objects that are not maps or lists are encoded through their `toJson`.
Future<void> replaceWithJson(File file, Object? value) async {
  await file.parent.create(recursive: true);
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(value));
  if (!Platform.isWindows) return replacePrivateFile(file.path, bytes);
  final temporary = File(uniqueTemporaryPath(file.path));
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    // Windows refuses to replace a file someone is reading, such as the
    // service loading it; reads are short, so try again shortly.
    for (var attempt = 1; ; attempt++) {
      try {
        await temporary.rename(file.path);
        return;
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
  } catch (_) {
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

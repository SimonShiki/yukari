import 'dart:convert';
import 'dart:io';

/// Replaces [file] with [value] encoded as pretty JSON, atomically: a reader
/// sees either the old or the new content, never a half-written file.
///
/// Objects that are not maps or lists are encoded through their `toJson`.
Future<void> replaceWithJson(File file, Object? value) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(
    const JsonEncoder.withIndent('  ').convert(value),
    flush: true,
  );
  // Windows refuses to replace a file someone is reading, such as the
  // service loading it; reads are short, so try again shortly.
  for (var attempt = 1; ; attempt++) {
    try {
      await temporary.rename(file.path);
      return;
    } on FileSystemException {
      if (!Platform.isWindows || attempt == 5) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
    }
  }
}

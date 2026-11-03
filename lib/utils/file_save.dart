import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Writes [content] as UTF-8 under [name] where the user chose to save it.
///
/// Returns false when the user dismissed the save dialog; throws when the
/// platform could not write the file. The suggested [name] carries the
/// extension the dialog preselects; file_picker 13 never appends one itself.
Future<bool> saveTextFile(
  String name,
  String content, {
  required String mimeType,
  String? dialogTitle,
}) => saveBytesFile(
  name,
  Uint8List.fromList(utf8.encode(content)),
  mimeType: mimeType,
  dialogTitle: dialogTitle,
);

/// Writes the binary [bytes] under [name] where the user chose to save it.
///
/// The binary counterpart of [saveTextFile], for files such as an exported GIF
/// that are already encoded.
Future<bool> saveBytesFile(
  String name,
  Uint8List bytes, {
  required String mimeType,
  String? dialogTitle,
}) async {
  final location = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );
  return location != null;
}

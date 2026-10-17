import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/utils/file_save.dart';

/// A platform saver that records what [saveTextFile] asked it to write.
final class _RecordingPicker extends FilePickerPlatform {
  _RecordingPicker({this.answer});

  /// What the save dialog answers; null stands for a dismissed dialog.
  final Uri? answer;

  String? fileName;
  Uint8List? bytes;
  String? mimeType;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    this.mimeType = mimeType;
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform original;
  setUp(() {
    original = FilePickerPlatform.instance;
  });
  tearDown(() {
    FilePickerPlatform.instance = original;
  });

  test('writes UTF-8 text with the requested name and MIME type', () async {
    final picker = _RecordingPicker(answer: Uri.file('/tmp/yukari.txt'));
    FilePickerPlatform.instance = picker;

    final written = await saveTextFile(
      'yukari-logs.txt',
      'line one\nline two\n',
      mimeType: 'text/plain',
    );

    expect(written, isTrue);
    expect(picker.fileName, 'yukari-logs.txt');
    expect(picker.mimeType, 'text/plain');
    expect(utf8.decode(picker.bytes!), 'line one\nline two\n');
  });

  test('reports a dismissed save dialog as not written', () async {
    FilePickerPlatform.instance = _RecordingPicker();

    final written = await saveTextFile(
      'yukari-logs.txt',
      'line\n',
      mimeType: 'text/plain',
    );

    expect(written, isFalse);
  });
}

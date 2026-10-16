import 'dart:convert';
import 'dart:io';

typedef Decode<T> = T Function(Object? json);
typedef Encode<T> = Object? Function(T value);

class StorageException implements Exception {
  StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StorageException: $message${cause != null ? ' ($cause)' : ''}';
}

final class JsonFileStore<T extends Object> {
  JsonFileStore({
    required this.file,
    required this.decode,
    required this.encode,
  });

  final File file;
  final Decode<T> decode;
  final Encode<T> encode;

  static const _encoder = JsonEncoder.withIndent('  ');

  /// Serializes writes so two saves never race on the same temporary file.
  Future<void> _writes = Future.value();

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    // Keep the chain alive after a failure so later writes still run.
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> load() async {
    try {
      return decode(jsonDecode(await file.readAsString()));
    } on FileSystemException catch (e) {
      throw StorageException('Failed to read ${file.path}', e);
    } on FormatException catch (e) {
      throw StorageException('Corrupt data in ${file.path}', e);
    } on TypeError catch (e) {
      throw StorageException('Schema mismatch in ${file.path}', e);
    }
  }

  Future<void> save(T value) => _enqueue(() async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(_encoder.convert(encode(value)), flush: true);
      await tmp.rename(file.path);
    } on FileSystemException catch (e) {
      throw StorageException('Failed to save ${file.path}', e);
    }
  });

  Future<bool> exists() => file.exists();

  Future<void> clear() => _enqueue(() async {
    if (await file.exists()) await file.delete();
  });
}

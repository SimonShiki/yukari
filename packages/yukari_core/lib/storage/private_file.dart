import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';

// The same on every Linux and Android architecture the app is built for.
const _writeOnly = 0x1,
    _create = 0x40,
    _exclusive = 0x80,
    _closeOnExec = 0x80000;
const _ownerReadWrite = 0x180; // 0600

final _libc = DynamicLibrary.process();
final _open = _libc
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Int32, VarArgs<(Uint32,)>),
      int Function(Pointer<Utf8>, int, int)
    >('open');
final _fchmod = _libc
    .lookupFunction<Int32 Function(Int32, Uint32), int Function(int, int)>(
      'fchmod',
    );
final _chmod = _libc
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Uint32),
      int Function(Pointer<Utf8>, int)
    >('chmod');
final _write = _libc
    .lookupFunction<
      IntPtr Function(Int32, Pointer<Uint8>, Size),
      int Function(int, Pointer<Uint8>, int)
    >('write');
final _fsync = _libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
  'fsync',
);
final _close = _libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
  'close',
);
final _unlink = _libc
    .lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>(
      'unlink',
    );
final _rename = _libc
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
      int Function(Pointer<Utf8>, Pointer<Utf8>)
    >('rename');

final _random = Random.secure();

/// A name beside [path] that no other writer picks: concurrent writes and a
/// file someone planted under a fixed name cannot collide with it.
String uniqueTemporaryPath(String path) {
  final suffix = [
    for (var i = 0; i < 8; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  return '$path.$pid-$suffix.tmp';
}

/// Replaces [path] with [bytes], readable and writable by its owner alone.
///
/// The bytes go to a new file created with that mode, so no one else can open
/// it even for a moment, and its name then replaces [path]: a reader sees the
/// old file or the new one, and a symlink at [path] is replaced rather than
/// written through. [beforeWrite] gets the open descriptor first, for a
/// caller that labels the file. POSIX only; Windows has no file modes.
void replacePrivateFile(
  String path,
  List<int> bytes, {
  void Function(int fd)? beforeWrite,
}) => using((arena) {
  final target = path.toNativeUtf8(allocator: arena);
  final temporaryPath = uniqueTemporaryPath(path);
  final temporary = temporaryPath.toNativeUtf8(allocator: arena);
  final fd = _open(
    temporary,
    _writeOnly | _create | _exclusive | _closeOnExec,
    _ownerReadWrite,
  );
  if (fd < 0) throw FileSystemException('Cannot create', temporaryPath);
  try {
    try {
      // The umask may have dropped bits; the mode must be exactly this.
      if (_fchmod(fd, _ownerReadWrite) != 0) {
        throw FileSystemException('Cannot restrict access', path);
      }
      beforeWrite?.call(fd);
      final buffer = arena<Uint8>(max(bytes.length, 1));
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      for (var written = 0; written < bytes.length;) {
        final count = _write(fd, buffer + written, bytes.length - written);
        if (count <= 0) throw FileSystemException('Cannot write', path);
        written += count;
      }
      // On disk before the name moves, so a crash leaves one whole file.
      if (_fsync(fd) != 0) throw FileSystemException('Cannot flush', path);
    } finally {
      _close(fd);
    }
    // Replaces the name itself, whatever it pointed at.
    if (_rename(temporary, target) != 0) {
      throw FileSystemException('Cannot replace', path);
    }
  } catch (_) {
    _unlink(temporary);
    rethrow;
  }
});

/// Makes the existing file [path] readable and writable by its owner alone,
/// for a file an older version wrote readable by everyone. POSIX only.
void restrictToOwner(String path) => using((arena) {
  if (_chmod(path.toNativeUtf8(allocator: arena), _ownerReadWrite) != 0) {
    throw FileSystemException('Cannot restrict access', path);
  }
});

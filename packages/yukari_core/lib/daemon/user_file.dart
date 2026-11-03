import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../storage/private_file.dart';

final _libc = DynamicLibrary.process();
final _setfsuid = _libc
    .lookupFunction<Int32 Function(Uint32), int Function(int)>('setfsuid');
final _getxattr = _libc
    .lookupFunction<
      IntPtr Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>, Size),
      int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>, int)
    >('getxattr');
final _fsetxattr = _libc
    .lookupFunction<
      Int32 Function(Int32, Pointer<Utf8>, Pointer<Void>, Size, Int32),
      int Function(int, Pointer<Utf8>, Pointer<Void>, int, int)
    >('fsetxattr');

/// Replaces [path] with [contents], written as the user [uid] rather than as
/// root, and readable by [uid] alone.
///
/// [uid] owns the directory, so it could point any name there at a file of
/// root's. Acting as [uid] for the file system leaves root's write only the
/// access [uid] has itself, and the file is created anew, never opened
/// through a symlink; see [replacePrivateFile]. With [label], it gets the
/// SELinux label of its directory, which files root creates in an app's
/// directory otherwise lack.
void writeAsUser(
  String path,
  String contents, {
  required int uid,
  bool label = false,
}) {
  // setfsuid answers the previous id, so a second call confirms the switch.
  final previous = _setfsuid(uid);
  try {
    if (_setfsuid(uid) != uid) {
      throw FileSystemException('Cannot act as user $uid', path);
    }
    replacePrivateFile(
      path,
      utf8.encode(contents),
      beforeWrite: label ? (fd) => _copyLabel(p.dirname(path), fd) : null,
    );
  } finally {
    _setfsuid(previous);
  }
}

/// Gives the open file [fd] the SELinux label of [directory].
void _copyLabel(String directory, int fd) => using((arena) {
  const capacity = 256;
  final name = 'security.selinux'.toNativeUtf8(allocator: arena);
  final value = arena<Uint8>(capacity).cast<Void>();
  final length = _getxattr(
    directory.toNativeUtf8(allocator: arena),
    name,
    value,
    capacity,
  );
  if (length < 0 || _fsetxattr(fd, name, value, length, 0) != 0) {
    throw FileSystemException('Cannot label the file for the app', directory);
  }
});

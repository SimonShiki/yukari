import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../backend/ipc/ipc_endpoint.dart';

/// Opens the socket the app connects to, and returns it with the token
/// peers must present; see [IpcEndpoint].
///
/// On Linux only [ownerUid] and root may open the socket. Elsewhere the
/// token is published into [dataDir], which only its owner can read.
Future<(ServerSocket, String?)> bindServiceSocket({
  required String dataDir,
  int? ownerUid,
}) async {
  if (!IpcEndpoint.usesUnixSocket) {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = base64Url.encode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
    try {
      await IpcEndpoint(
        server.address,
        server.port,
        token: token,
      ).publish(dataDir);
      // On Android, hand the file that root wrote over to the app.
      if (!Platform.isWindows) {
        final file = p.join(dataDir, IpcEndpoint.tokenFile);
        _restrict(file, ownerUid);
        _copyLabel(dataDir, file);
      }
    } catch (_) {
      await server.close();
      rethrow;
    }
    return (server, token);
  }
  const path = IpcEndpoint.linuxSocket;
  await Directory(p.dirname(path)).create(recursive: true);
  // A crashed service leaves its socket behind, which blocks binding.
  if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
    await File(path).delete();
  }
  final server = await ServerSocket.bind(
    InternetAddress(path, type: InternetAddressType.unix),
    0,
  );
  try {
    _restrict(path, ownerUid);
  } catch (_) {
    await server.close();
    rethrow;
  }
  return (server, null);
}

/// Makes [path] readable and writable by [uid] and root only.
void _restrict(String path, int? uid) => using((arena) {
  final libc = DynamicLibrary.process();
  final chown = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Uint32, Uint32),
        int Function(Pointer<Utf8>, int, int)
      >('chown');
  final chmod = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Uint32),
        int Function(Pointer<Utf8>, int)
      >('chmod');
  final native = path.toNativeUtf8(allocator: arena);
  // A gid of -1 keeps the group unchanged.
  if (uid != null && chown(native, uid, 0xFFFFFFFF) != 0) {
    throw FileSystemException('Cannot hand over to user $uid', path);
  }
  if (chmod(native, 0x180 /* 0600 */) != 0) {
    throw FileSystemException('Cannot restrict access', path);
  }
});

/// Gives [path] the SELinux label of [directory]. Files root creates in an
/// app's data directory otherwise keep a label the app may not read.
void _copyLabel(String directory, String path) => using((arena) {
  final libc = DynamicLibrary.process();
  final getxattr = libc
      .lookupFunction<
        IntPtr Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>, Size),
        int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>, int)
      >('getxattr');
  final setxattr = libc
      .lookupFunction<
        Int32 Function(
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Void>,
          Size,
          Int32,
        ),
        int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>, int, int)
      >('setxattr');
  const capacity = 256;
  final name = 'security.selinux'.toNativeUtf8(allocator: arena);
  final label = arena<Uint8>(capacity).cast<Void>();
  final length = getxattr(
    directory.toNativeUtf8(allocator: arena),
    name,
    label,
    capacity,
  );
  if (length < 0 ||
      setxattr(path.toNativeUtf8(allocator: arena), name, label, length, 0) !=
          0) {
    throw FileSystemException('Cannot label the endpoint for the app', path);
  }
});

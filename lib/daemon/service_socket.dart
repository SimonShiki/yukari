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
/// On Linux only [ownerUid] and root may open the socket. On Windows the
/// token is published into [dataDir], which only its owner can read.
Future<(ServerSocket, String?)> bindServiceSocket({
  required String dataDir,
  int? ownerUid,
}) async {
  if (Platform.isWindows) {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = base64Url.encode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
    await IpcEndpoint(
      server.address,
      server.port,
      token: token,
    ).publish(dataDir);
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
    throw FileSystemException('Cannot hand the socket to user $uid', path);
  }
  if (chmod(native, 0x180 /* 0600 */) != 0) {
    throw FileSystemException('Cannot restrict the socket', path);
  }
});

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../backend/ipc/ipc_endpoint.dart';
import '../backend/security_windows.dart';
import 'peer_credentials.dart';
import 'user_file.dart';

/// The socket the app connects to, and how the service tells the app apart
/// from other processes: by the [token] it must present, or by [admits].
typedef ServiceSocket = ({
  ServerSocket server,
  String? token,
  bool Function(Socket peer)? admits,
});

/// Opens the socket the app connects to; see [IpcEndpoint].
///
/// On Linux the kernel names each peer, and only [ownerUid] and root are
/// admitted. Elsewhere a token is recorded where only the owner, [ownerSid]
/// on Windows and [ownerUid] on Android, can read it besides administrators.
Future<ServiceSocket> bindServiceSocket({
  required String dataDir,
  int? ownerUid,
  String? ownerSid,
}) async {
  if (!IpcEndpoint.usesUnixSocket) {
    // Android's app could not read a token root writes for itself.
    if (!Platform.isWindows && ownerUid == null) {
      throw ArgumentError.notNull('ownerUid');
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = base64Url.encode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
    try {
      final file = IpcEndpoint.file(dataDir);
      final contents = IpcEndpoint(
        server.address,
        server.port,
        token: token,
      ).encode();
      if (Platform.isWindows) {
        await Directory(p.dirname(file)).create(recursive: true);
        // Administrators alone, when no one installed it for themselves.
        writeRestrictedFile(file, contents, ownerSid ?? 'S-1-5-32-544');
      } else {
        writeAsUser(file, contents, uid: ownerUid!, label: true);
      }
    } catch (_) {
      await server.close();
      rethrow;
    }
    return (server: server, token: token, admits: null);
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
    // The kernel's word on each peer decides; see [admitOwner]. The mode
    // only keeps others from connecting at all.
    _restrict(path, ownerUid);
  } catch (_) {
    await server.close();
    rethrow;
  }
  return (server: server, token: null, admits: admitOwner(ownerUid));
}

/// Makes the socket [path] readable and writable by [uid] and root only.
///
/// [path] lies in a directory only root writes, so it is the socket itself.
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
  // Before the hand-over: changing the mode of another's file takes
  // CAP_FOWNER, which the systemd unit does not grant.
  if (chmod(native, 0x180 /* 0600 */) != 0) {
    throw FileSystemException('Cannot restrict access', path);
  }
  // A gid of -1 keeps the group unchanged.
  if (uid != null && chown(native, uid, 0xFFFFFFFF) != 0) {
    throw FileSystemException('Cannot hand over to user $uid', path);
  }
});

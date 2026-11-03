import 'dart:io';
import 'dart:typed_data';

// The same on every Linux architecture this service is built for.
const _solSocket = 1, _soPeerCred = 17;

/// The user id of the process at the other end of the Unix socket [socket],
/// as the kernel recorded it when that process connected; null when the
/// kernel does not say.
int? peerUid(Socket socket) {
  try {
    // struct ucred { pid_t pid; uid_t uid; gid_t gid; }
    final option = RawSocketOption(_solSocket, _soPeerCred, Uint8List(12));
    final credentials = socket.getRawOption(option);
    return ByteData.sublistView(credentials).getUint32(4, Endian.host);
  } on Object {
    return null;
  }
}

/// Admits peers running as root or as [ownerUid], and no one else; see
/// [peerUid]. Without [ownerUid], only root.
bool Function(Socket socket) admitOwner(int? ownerUid) => (socket) {
  final uid = peerUid(socket);
  return uid != null && (uid == 0 || uid == ownerUid);
};

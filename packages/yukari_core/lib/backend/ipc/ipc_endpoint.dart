import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../system/windows_service.dart';

/// Where the service listens for the app, and how the app proves itself.
///
/// On Linux the service listens on a Unix socket and admits the installing
/// user and root alone. Windows has no Unix sockets in Dart, and Android has
/// no /run and keeps apps from root's sockets, so there the service listens on
/// loopback and records the port and a random token in [tokenFile], which only
/// that user and administrators read.
final class IpcEndpoint {
  const IpcEndpoint(this.address, this.port, {this.token});

  static const linuxSocket = '/run/yukari/yukari.sock';
  static const tokenFile = 'service.json';

  /// Whether the service listens on [linuxSocket] rather than on loopback.
  ///
  /// On Android the service is a Linux build, run by a root module, so it
  /// checks for Android itself.
  static bool get usesUnixSocket =>
      Platform.isLinux && !File('/system/build.prop').existsSync();

  final InternetAddress address;
  final int port;
  final String? token;

  /// Where the service serving the data directory [dataDir] records its
  /// endpoint.
  ///
  /// The Windows service keeps it out of [dataDir], which the user could
  /// point elsewhere for LocalSystem to write. Android keeps it in [dataDir],
  /// as the app cannot read root's directories, and writes it as the app.
  static String file(String dataDir) => Platform.isWindows
      ? p.join(WindowsService.runDirectory, tokenFile)
      : p.join(dataDir, tokenFile);

  /// The endpoint of the service that serves the data directory [dataDir].
  static Future<IpcEndpoint> locate(String dataDir) async {
    if (usesUnixSocket) {
      return IpcEndpoint(
        InternetAddress(linuxSocket, type: InternetAddressType.unix),
        0,
      );
    }
    String text;
    try {
      text = await File(file(dataDir)).readAsString();
    } on FileSystemException {
      if (!Platform.isWindows) rethrow;
      // Services before version 5 wrote it into the data directory; reading
      // it lets the app offer them the update.
      text = await File(p.join(dataDir, tokenFile)).readAsString();
    }
    final json = jsonDecode(text) as Map<String, Object?>;
    return IpcEndpoint(
      InternetAddress.loopbackIPv4,
      json['port'] as int,
      token: json['token'] as String,
    );
  }

  /// The contents of [tokenFile] for this endpoint; see [locate].
  String encode() => jsonEncode({'port': port, 'token': token});
}

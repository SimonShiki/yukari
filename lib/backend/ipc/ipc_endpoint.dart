import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the service listens for the app, and how the app proves itself.
///
/// On Linux the service listens on a Unix socket that only the installing
/// user and root may open. Windows has no Unix sockets in Dart, so the
/// service listens on loopback and writes the port and a random token into
/// the user's data directory, which only that user and administrators read.
final class IpcEndpoint {
  const IpcEndpoint(this.address, this.port, {this.token});

  static const linuxSocket = '/run/yukari/yukari.sock';
  static const windowsFile = 'service.json';

  final InternetAddress address;
  final int port;
  final String? token;

  /// The endpoint of the service that serves the data directory [dataDir].
  static Future<IpcEndpoint> locate(String dataDir) async {
    if (!Platform.isWindows) {
      return IpcEndpoint(
        InternetAddress(linuxSocket, type: InternetAddressType.unix),
        0,
      );
    }
    final file = File(p.join(dataDir, windowsFile));
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return IpcEndpoint(
      InternetAddress.loopbackIPv4,
      json['port'] as int,
      token: json['token'] as String,
    );
  }

  /// Records this endpoint for the app; see [locate].
  Future<void> publish(String dataDir) async {
    final file = File(p.join(dataDir, windowsFile));
    await file.writeAsString(jsonEncode({'port': port, 'token': token}));
  }
}

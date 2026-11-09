// Unix sockets, SO_PEERCRED and setfsuid are Linux's.
@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari_core/backend/privilege.dart';
import 'package:yukari_core/daemon/peer_credentials.dart';
import 'package:yukari_core/daemon/user_file.dart';

void main() {
  late Directory directory;
  final uid = effectiveUid()!;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yukari_socket_');
    addTearDown(() => directory.delete(recursive: true));
  });

  group('peer credentials', () {
    /// The server's end of a connection this process makes to itself.
    Future<Socket> connectToSelf() async {
      final address = InternetAddress(
        p.join(directory.path, 's.sock'),
        type: InternetAddressType.unix,
      );
      final server = await ServerSocket.bind(address, 0);
      addTearDown(server.close);
      final peer = server.first;
      final client = await Socket.connect(address, 0);
      addTearDown(client.destroy);
      final accepted = await peer;
      addTearDown(accepted.destroy);
      return accepted;
    }

    test('name the user the kernel says connected', () async {
      expect(peerUid(await connectToSelf()), uid);
    });

    test('admit the owner and root alone', () async {
      final peer = await connectToSelf();

      expect(admitOwner(uid)(peer), isTrue);
      expect(admitOwner(uid + 1)(peer), uid == 0);
      expect(admitOwner(null)(peer), uid == 0);
    });
  });

  group('writeAsUser', () {
    test('writes a file only its user reads', () {
      final path = p.join(directory.path, 'service.json');

      writeAsUser(path, '{"port":1}', uid: uid);

      expect(File(path).readAsStringSync(), '{"port":1}');
      expect(File(path).statSync().mode & 0x1FF, 0x180 /* 0600 */);
      expect(directory.listSync().map((entry) => entry.path), [
        path,
      ], reason: 'no temporary file is left behind');
    });

    test('replaces a symlink rather than writing through it', () {
      final victim = File(p.join(directory.path, 'victim'))
        ..writeAsStringSync('keep');
      final path = p.join(directory.path, 'service.json');
      Link(path).createSync(victim.path);
      Link('$path.tmp').createSync(victim.path);

      writeAsUser(path, 'new', uid: uid);

      expect(victim.readAsStringSync(), 'keep');
      expect(FileSystemEntity.isLinkSync(path), isFalse);
      expect(File(path).readAsStringSync(), 'new');
    });

    test('fails rather than writing as root when it cannot switch', () {
      final path = p.join(directory.path, 'service.json');

      expect(
        () => writeAsUser(path, 'x', uid: uid + 1),
        uid == 0 ? returnsNormally : throwsA(isA<FileSystemException>()),
      );
      if (uid != 0) expect(File(path).existsSync(), isFalse);
    });
  });
}

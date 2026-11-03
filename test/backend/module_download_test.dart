import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/backend/system/module_download.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late Map<String, List<int>> served;
  late String publicKey;
  late SimpleKeyPair keys;
  final module = utf8.encode('module zip');

  Uri url(String name) => Uri.parse('http://127.0.0.1:${server.port}/$name');

  /// Signs [bytes] as CI does: Ed25519 over their SHA-256 digest.
  Future<List<int>> sign(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return (await Ed25519().sign(digest.bytes, keyPair: keys)).bytes;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yukari_module');
    addTearDown(() => directory.delete(recursive: true));
    keys = await Ed25519().newKeyPair();
    publicKey = base64.encode((await keys.extractPublicKey()).bytes);
    served = {'m.zip': module, 'm.zip.sig': await sign(module)};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final body = served[request.uri.pathSegments.last];
      request.response.statusCode = body == null ? 404 : 200;
      if (body != null) request.response.add(body);
      await request.response.close();
    });
  });

  File zip() => File(p.join(directory.path, 'm.zip'));

  Future<void> download({String? key}) => downloadSignedModule(
    url('m.zip'),
    url('m.zip.sig'),
    zip(),
    publicKey: key ?? publicKey,
  );

  test('keeps a module signed by the key', () async {
    await download();

    expect(await zip().readAsBytes(), module);
  });

  test('refuses and removes a module that was changed', () async {
    served['m.zip'] = utf8.encode('evil zip');

    await expectLater(download(), throwsA(isA<ModuleVerificationException>()));
    expect(zip().existsSync(), isFalse);
  });

  test('refuses a module signed by another key', () async {
    final other = await Ed25519().newKeyPair();
    final otherKey = base64.encode((await other.extractPublicKey()).bytes);

    await expectLater(
      download(key: otherKey),
      throwsA(isA<ModuleVerificationException>()),
    );
    expect(zip().existsSync(), isFalse);
  });

  test('refuses a module without a signature', () async {
    served.remove('m.zip.sig');

    await expectLater(download(), throwsA(isA<HttpException>()));
    expect(zip().existsSync(), isFalse);
  });

  test('refuses an oversized signature before downloading', () async {
    served['m.zip.sig'] = List.filled(1 << 16, 0);

    await expectLater(download(), throwsA(isA<HttpException>()));
    expect(zip().existsSync(), isFalse);
  });

  test('refuses every module while no key is set up', () async {
    await expectLater(
      download(key: ''),
      throwsA(isA<ModuleVerificationException>()),
    );
    expect(zip().existsSync(), isFalse);
  });
}

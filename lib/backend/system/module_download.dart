import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// The Ed25519 public key `.github/workflows/release.yml` signs the module with,
/// from the `SERVICE_MODULE_SIGNING_KEY` secret, as base64 of its 32 bytes.
const moduleSigningKey = '0T2G2Vv5YPTCsI6bYIP3T5v/9F8z/myEgBicKCbZva8=';

/// Thrown when a downloaded module is not the one CI signed.
final class ModuleVerificationException implements Exception {
  const ModuleVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads [module] into [file] and checks it against [signature], the
/// Ed25519 signature of its SHA-256 digest by [publicKey], reporting progress
/// to [onProgress].
///
/// Root installs the module, so nothing is left in [file] unless it checks
/// out; see [ModuleVerificationException].
Future<void> downloadSignedModule(
  Uri module,
  Uri signature,
  File file, {
  String publicKey = moduleSigningKey,
  void Function(double? progress)? onProgress,
}) async {
  final client = HttpClient();
  try {
    if (publicKey.isEmpty) {
      throw const ModuleVerificationException(
        'This build has no key to check the service module with',
      );
    }
    final key = SimplePublicKey(
      base64.decode(publicKey),
      type: KeyPairType.ed25519,
    );
    // A signature is 64 bytes; anything longer is not one.
    final signed = await _get(client, signature, limit: 64);
    final digest = await _download(client, module, file, onProgress);
    final valid = await Ed25519().verify(
      digest,
      signature: Signature(signed, publicKey: key),
    );
    if (!valid) {
      throw const ModuleVerificationException(
        'The downloaded service module is not signed by Yukari',
      );
    }
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  } finally {
    client.close(force: true);
  }
}

/// Fetches [uri] into memory, refusing more than [limit] bytes.
Future<Uint8List> _get(HttpClient client, Uri uri, {required int limit}) async {
  final response = await _open(client, uri);
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response) {
    bytes.add(chunk);
    if (bytes.length > limit) {
      throw HttpException('Unexpectedly large response', uri: uri);
    }
  }
  return bytes.takeBytes();
}

/// Streams [uri] into [file] and answers its SHA-256 digest.
Future<List<int>> _download(
  HttpClient client,
  Uri uri,
  File file,
  void Function(double? progress)? onProgress,
) async {
  final response = await _open(client, uri);
  final total = response.contentLength;
  final hash = const DartSha256().newHashSink();
  var received = 0;
  final sink = file.openWrite();
  try {
    await sink.addStream(
      response.map((chunk) {
        received += chunk.length;
        hash.add(chunk);
        onProgress?.call(total > 0 ? received / total : null);
        return chunk;
      }),
    );
  } finally {
    await sink.close();
  }
  hash.close();
  return hash.hashSync().bytes;
}

Future<HttpClientResponse> _open(HttpClient client, Uri uri) async {
  final response = await (await client.getUrl(uri)).close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException(
      'Could not download ${uri.pathSegments.last}: '
      'HTTP ${response.statusCode}',
      uri: uri,
    );
  }
  return response;
}

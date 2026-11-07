import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Generates a cryptographically secure random X25519 private key for
/// EasyTier secure mode.
///
/// Returns the 32-byte private key, base64-encoded.
String generatePrivateKey() {
  final random = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    bytes[i] = random.nextInt(256);
  }
  return base64.encode(bytes);
}

/// Derives an X25519 public key from a private key with Curve25519 scalar
/// multiplication.
///
/// [privateKeyBase64] must be a base64-encoded 32-byte X25519 private key.
/// Returns the base64-encoded 32-byte public key.
/// Throws [ArgumentError] if the private key format is invalid.
Future<String> derivePublicKey(String privateKeyBase64) async {
  try {
    final privateBytes = base64.decode(privateKeyBase64);
    if (privateBytes.length != 32) {
      throw ArgumentError(
        'Private key must be 32 bytes, got ${privateBytes.length}',
      );
    }

    final algorithm = X25519();

    // The private key is the seed: the scalar base multiplication happens
    // inside newKeyPairFromSeed.
    final keyPair = await algorithm.newKeyPairFromSeed(privateBytes);
    final extractedPublicKey = await keyPair.extractPublicKey();

    return base64.encode(extractedPublicKey.bytes);
  } catch (e) {
    throw ArgumentError('Invalid private key format: $e');
  }
}

/// Generates a cryptographically secure random string to use as a network
/// secret; peers authenticate each other with it.
String generateSecretKey({int length = 32}) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

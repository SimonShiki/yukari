import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Generates a cryptographically secure random X25519 private key
/// for EasyTier secure mode (compatible with QtEasyTier).
///
/// Returns a base64-encoded 32-byte private key string.
String generatePrivateKey() {
  final random = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    bytes[i] = random.nextInt(256);
  }
  return base64.encode(bytes);
}

/// Derives an X25519 public key from a private key.
///
/// This uses Curve25519 scalar multiplication to derive the public key,
/// matching the implementation in QtEasyTier and EasyTier.
///
/// [privateKeyBase64] must be a base64-encoded 32-byte X25519 private key.
/// Returns the base64-encoded 32-byte public key.
/// Throws [ArgumentError] if the private key format is invalid.
Future<String> derivePublicKey(String privateKeyBase64) async {
  try {
    final privateBytes = base64.decode(privateKeyBase64);
    if (privateBytes.length != 32) {
      throw ArgumentError('Private key must be 32 bytes, got ${privateBytes.length}');
    }

    // Create X25519 algorithm instance
    final algorithm = X25519();

    // Derive the public key using X25519 scalar base multiplication
    final keyPair = await algorithm.newKeyPairFromSeed(privateBytes);
    final extractedPublicKey = await keyPair.extractPublicKey();

    return base64.encode(extractedPublicKey.bytes);
  } catch (e) {
    throw ArgumentError('Invalid private key format: $e');
  }
}

/// Generates a random secret key for network authentication.
///
/// Returns a cryptographically secure random string suitable for use
/// as a network secret.
String generateSecretKey({int length = 32}) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

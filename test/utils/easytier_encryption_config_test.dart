import 'package:flutter_test/flutter_test.dart';
import 'package:toml/toml.dart';
import 'package:yukari/utils/easytier_config_parser.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/utils/easytier_config_serializer.dart';

void main() {
  final algorithms = <String, (EncryptionAlgorithm, String)>{
    'xor': (EncryptionAlgorithm.xor, 'xor'),
    'aes-gcm': (EncryptionAlgorithm.aesGcm, 'aes-gcm'),
    'openssl-aes-gcm': (EncryptionAlgorithm.aesGcm, 'aes-gcm'),
    'aes-256-gcm': (EncryptionAlgorithm.aes256Gcm, 'aes-256-gcm'),
    'openssl-aes-256-gcm': (EncryptionAlgorithm.aes256Gcm, 'aes-256-gcm'),
    'chacha20': (EncryptionAlgorithm.chacha20, 'chacha20'),
    'chacha20-poly1305': (EncryptionAlgorithm.chacha20, 'chacha20'),
    'openssl-chacha20': (EncryptionAlgorithm.chacha20, 'chacha20'),
  };

  for (final entry in algorithms.entries) {
    test('preserves ${entry.key} through import and export', () {
      for (final spelling in [entry.key, entry.key.toUpperCase()]) {
        final network = parseEasyTierConfig('''
[flags]
encryption_algorithm = "$spelling"
''');
        expect(network.flags.encryptionAlgorithm, entry.value.$1);
        final exported = network.toEasyTierToml();
        final flags = TomlDocument.parse(exported).toMap()['flags'] as Map;
        expect(flags['encryption_algorithm'], entry.value.$2);
        expect(
          parseEasyTierConfig(exported).flags.encryptionAlgorithm,
          entry.value.$1,
        );
      }
    });
  }

  for (final value in [
    '"unknown"',
    '"aes-gcm-256"',
    '""',
    '42',
    'true',
    '[]',
    '{}',
  ]) {
    test('rejects encryption_algorithm=$value instead of replacing it', () {
      expect(
        () => parseEasyTierConfig('[flags]\nencryption_algorithm = $value\n'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('encryption_algorithm'),
          ),
        ),
      );
    });
  }

  test('uses model defaults when the algorithm is omitted', () {
    for (final config in ['', '[flags]', '[flags]\nmtu = 1400']) {
      expect(
        parseEasyTierConfig(config).flags.encryptionAlgorithm,
        NetworkFlags().encryptionAlgorithm,
      );
    }
  });

  test('rejects an unknown algorithm even when encryption is disabled', () {
    expect(
      () => parseEasyTierConfig('''
[flags]
enable_encryption = false
encryption_algorithm = "unknown"
'''),
      throwsFormatException,
    );
  });
}

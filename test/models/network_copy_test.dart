import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/models.dart';

void main() {
  for (final field in ['acl', 'additionalFlags', 'additionalConfiguration']) {
    test('copy isolates edits to $field in both directions', () {
      final original = Network()
        ..acl = _configuration()
        ..additionalFlags = _configuration()
        ..additionalConfiguration = _configuration();
      final copy = original.copy();
      expect(copy.toJson(), original.toJson());
      final originalMap = original.toJson()[field] as Map<String, Object?>;
      final copiedMap = copy.toJson()[field] as Map<String, Object?>;

      copiedMap['added'] = 'copy';
      (copiedMap['list'] as List<Object?>).add('copy');
      ((copiedMap['list'] as List<Object?>)[1] as List<Object?>).add(3);
      _nestedMap(copiedMap)['action'] = 'copy';
      (_nestedMap(copiedMap)['groups'] as List<Object?>).add('copy');

      expect(originalMap, _configuration());
      originalMap['added'] = 'original';
      _nestedMap(originalMap)['action'] = 'original';
      (_nestedMap(originalMap)['groups'] as List<Object?>).add('original');
      expect(copiedMap['added'], 'copy');
      expect(_nestedMap(copiedMap)['action'], 'copy');
      expect(_nestedMap(copiedMap)['groups'], ['admin', 'copy']);
    });
  }

  test('copy preserves optional and immutable values', () {
    final timestamp = DateTime.utc(2026, 1, 2);
    final original = Network()
      ..createdAt = timestamp
      ..updatedAt = timestamp
      ..additionalConfiguration = {'timestamp': timestamp};
    final copy = original.copy();

    expect(copy.acl, isNull);
    expect(copy.additionalFlags, isEmpty);
    expect(copy.additionalConfiguration['timestamp'], timestamp);
    expect(copy.createdAt, timestamp);
    expect(copy.updatedAt, timestamp);
  });
}

Map<String, Object?> _configuration() => {
  'enabled': true,
  'limit': 42,
  'ratio': 1.5,
  'optional': null,
  'list': <Object?>[
    'entry',
    <Object?>[1, 2],
  ],
  'nested': <String, Object?>{
    'rules': <Object?>[
      <String, Object?>{
        'action': 'allow',
        'groups': <Object?>['admin'],
      },
    ],
  },
};

Map<String, Object?> _nestedMap(Map<String, Object?> configuration) =>
    ((configuration['nested'] as Map<String, Object?>)['rules']
                as List<Object?>)
            .single
        as Map<String, Object?>;

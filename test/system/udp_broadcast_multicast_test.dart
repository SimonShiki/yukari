import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/system/udp_broadcast_multicast.dart';

void main() {
  test('parses groups per interface and skips link-local control groups', () {
    const data = '''
Idx Device    : Count Querier Group    Users Timer Reporter
2   eth0      :     3      V3
                010000E0     1 0:00000000 0
                3C0200E0     2 0:00000000 0
                FAFFFFEF     1 0:00000000 0
12  wlan0     :     1      V2
                010100E0     1 0:00000000 0
7   et_12     :     1      V3
                010000E0     1 0:00000000 0
''';
    final groups = parseProcNetIgmp(data, byteOrder: Endian.little);
    expect(groups, {
      'eth0': {0xe000023c, 0xeffffffa},
      'wlan0': {0xe0000101},
      'et_12': <int>{},
    });
    expect(multicastGroupsForInterfaces(groups, ['wlan0'], {0xeffffffa}), {
      0xe0000101,
    });
  });

  test('caps the union at 20 and prioritizes existing memberships', () {
    final groups = {
      'eth0': {for (var i = 0; i < 20; i++) 0xe0000100 + i},
      'wlan0': {0xeffffffa, 0xe0000100},
      'et_12': {0xeffffffb},
    };
    final desired = multicastGroupsForInterfaces(
      groups,
      ['eth0', 'wlan0'],
      {0xeffffffa, 0xe0000103, 0xeffffffc},
    );
    expect(desired, hasLength(20));
    expect(desired, containsAll([0xeffffffa, 0xe0000103]));
    expect(desired, isNot(contains(anyOf(0xeffffffb, 0xeffffffc))));
  });

  test('empty physical links produce no memberships', () {
    expect(
      multicastGroupsForInterfaces(
        {
          'eth0': {0xe000023c},
        },
        [],
        {},
      ),
      isEmpty,
    );
  });

  test('accepts native words on big-endian hosts', () {
    const data = '2 eth0 : 1 V3\n     E000023C 1 0:00000000 0';
    expect(parseProcNetIgmp(data, byteOrder: Endian.big), {
      'eth0': {0xe000023c},
    });
  });
}

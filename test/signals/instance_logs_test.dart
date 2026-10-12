import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/signals/instance_logs.dart';

String _event(int n) =>
    '{"time":"2026-10-12T21:21:${n.toString().padLeft(2, '0')}+08:00","event":{"PeerAdded":$n}}';

void main() {
  setUp(() => clearInstanceLogs('n1'));

  test('merges only events newer than the latest recorded one', () {
    recordInstanceEvents('n1', [_event(2), _event(1)]);
    final first = instanceLogs('n1').value;
    recordInstanceEvents('n1', [_event(4), _event(3), _event(2), _event(1)]);
    final logs = instanceLogs('n1').value;

    expect(logs.map((e) => e.raw), [
      _event(4),
      _event(3),
      _event(2),
      _event(1),
    ]);
    // Existing entries are kept, not re-parsed.
    expect(identical(logs[2], first[0]), isTrue);
  });

  test('keeps the history when nothing new arrived', () {
    recordInstanceEvents('n1', [_event(1)]);
    final before = instanceLogs('n1').value;
    recordInstanceEvents('n1', [_event(1)]);
    expect(identical(instanceLogs('n1').value, before), isTrue);
  });

  test('caps the history', () {
    for (var n = 0; n < maxLogEntries + 5; n++) {
      recordInstanceEvents('n1', ['{"n":$n}']);
    }
    final logs = instanceLogs('n1').value;
    expect(logs, hasLength(maxLogEntries));
    expect(logs.first.raw, '{"n":${maxLogEntries + 4}}');
  });
}

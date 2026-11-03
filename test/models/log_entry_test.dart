import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/l10n/generated/app_localizations_en.dart';
import 'package:yukari/l10n/generated/app_localizations_zh.dart';
import 'package:yukari_core/models/log_entry.dart';
import 'package:yukari/widgets/log_entry/log_summary.dart';

const _connAdded =
    '{"time":"2026-10-12T21:21:42.747707393+08:00","event":{"PeerConnAdded":'
    '{"conn_id":"3f6a","my_peer_id":1962988619,"peer_id":1269433021,'
    '"tunnel":{"tunnel_type":"tcp","local_addr":{"url":"tcp://198.18.0.1:38897"},'
    '"remote_addr":{"url":"tcp://47.116.42.222:21010"}},'
    '"stats":{"rx_bytes":"272"},"secure_auth_level":"NetworkSecretConfirmed"}}}';

void main() {
  test('parses newtype variants', () {
    final entry = LogEntry.parse(
      '{"time":"2026-10-12T21:21:42.713912353+08:00","event":{"PeerAdded":1269433021}}',
    );
    expect(entry.kind, 'PeerAdded');
    expect(entry.category, LogCategory.peer);
    expect(entry.severity, LogSeverity.success);
    expect(
      formatLogSummary(entry, AppLocalizationsEn()),
      'Peer 1269433021 joined',
    );
    expect(entry.time, DateTime.utc(2026, 10, 12, 13, 21, 42, 713, 912));
  });

  test('parses struct variants and flattens their details', () {
    final entry = LogEntry.parse(_connAdded);
    expect(
      formatLogSummary(entry, AppLocalizationsEn()),
      'Connected to peer 1269433021 via tcp://47.116.42.222:21010',
    );
    expect(
      entry.details,
      contains(('tunnel.remote_addr', 'tcp://47.116.42.222:21010')),
    );
    expect(entry.details, contains(('stats.rx_bytes', '272')));
  });

  test('parses tuple and unit variants', () {
    final error = LogEntry.parse(
      '{"time":"2026-10-12T21:21:42+08:00","event":{"ConnectError":'
      '["tcp://1.2.3.4:11010","v4","timeout"]}}',
    );
    expect(error.severity, LogSeverity.error);
    expect(error.category, LogCategory.connection);
    expect(
      formatLogSummary(error, AppLocalizationsEn()),
      'Cannot connect to tcp://1.2.3.4:11010 (v4): timeout',
    );
    expect(error.details, contains(('[2]', 'timeout')));

    final unit = LogEntry.parse(
      '{"time":"2026-10-12T21:21:42+08:00","event":"CredentialChanged"}',
    );
    expect(formatLogSummary(unit, AppLocalizationsEn()), 'Credential changed');
    expect(unit.category, LogCategory.system);
  });

  test('formats Chinese summaries and absent options', () {
    final entry = LogEntry.parse('{"event":{"PeerAdded":42}}');
    expect(formatLogSummary(entry, AppLocalizationsZh()), '节点 42 已加入');
    final missing = LogEntry.parse(
      '{"event":{"DhcpIpv4Changed":[null,"10.0.0.1"]}}',
    );
    expect(
      formatLogSummary(missing, AppLocalizationsZh()),
      'DHCP IPv4 已从 无 更改为 10.0.0.1',
    );
  });

  test('keeps malformed lines instead of throwing', () {
    for (final raw in ['not json', '[]', '{"event":{"A":1,"B":2}}']) {
      final entry = LogEntry.parse(raw);
      expect(entry.kind, 'Unknown');
      expect(entry.severity, LogSeverity.error);
      expect(entry.raw, raw);
    }
  });
}

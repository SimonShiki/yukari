import 'package:signals/signals.dart';

import '../models/log_entry.dart';

/// Upper bound of entries kept per network, newest first.
const maxLogEntries = 2000;

final Map<String, Signal<List<LogEntry>>> _logs = {};

/// Log history of the network stored under [id], newest first.
///
/// EasyTier only keeps its 20 most recent events, so the history is built up
/// by [recordInstanceEvents] each time the instance is collected.
ReadonlySignal<List<LogEntry>> instanceLogs(String id) =>
    _logs.putIfAbsent(id, () => signal(const []));

/// Merges [events], newest first as reported by EasyTier, into the history.
void recordInstanceEvents(String id, List<String> events) {
  final log = _logs.putIfAbsent(id, () => signal(const []));
  final current = log.peek();
  final known = current.isEmpty ? -1 : events.indexOf(current.first.raw);
  final fresh = known == -1 ? events : events.sublist(0, known);
  if (fresh.isEmpty) return;
  log.value = List.unmodifiable([
    ...fresh.map(LogEntry.parse),
    ...current.take(maxLogEntries - fresh.length),
  ]);
}

/// Forgets the history, such as when the network restarts or is deleted.
void clearInstanceLogs(String id) => _logs[id]?.value = const [];

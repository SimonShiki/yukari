part of 'network_instance_controller.dart';

/// The logs tab's filters, their counts and the expanded entries.
extension NetworkInstanceLogs on NetworkInstanceController {
  /// How many entries [category] would show, for its filter chip.
  ReadonlySignal<int> count(LogFilter category) => _counts.putIfAbsent(
    category,
    () => computed(() => _matching(category).length),
  );

  /// Whether [entry] is expanded.
  bool isExpanded(LogEntry entry) => expanded.value.contains(entry.raw);

  /// Expands or collapses [entry].
  void toggleExpanded(LogEntry entry) {
    final next = {...expanded.value};
    next.contains(entry.raw)
        ? next.remove(entry.raw)
        : next.add(entry.raw);
    expanded.value = next;
  }

  /// Selects the log [category] the logs tab shows.
  void selectFilter(LogFilter category) => filter.value = category;

  List<LogEntry> _matching(LogFilter category) => [
    for (final entry in logs.value)
      if (switch (category) {
        LogFilter.all => true,
        LogFilter.errors => entry.severity == LogSeverity.error,
        LogFilter.peers => entry.category == LogCategory.peer,
        LogFilter.connections => entry.category == LogCategory.connection,
        LogFilter.listeners => entry.category == LogCategory.listener,
      })
        entry,
  ];
}

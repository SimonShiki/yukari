import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/log_entry.dart';

/// A log entry in a segmented list that expands to show its details.
class LogEntryTile extends StatelessWidget {
  const LogEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.totalCount,
    required this.expanded,
    required this.onToggle,
  });

  final LogEntry entry;
  final int index;
  final int totalCount;
  final bool expanded;
  final VoidCallback onToggle;

  static const _monospace = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Consolas', 'Menlo'],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Severity is carried by shape and icon too, not by color alone.
    final (shape, container, onContainer) = switch (entry.severity) {
      LogSeverity.error => (
        Shapes.softBurst,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      LogSeverity.warning => (
        Shapes.pentagon,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      LogSeverity.success => (
        Shapes.c9SidedCookie,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      LogSeverity.info => (
        Shapes.circle,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };

    return M3EExpandableSegmentedItem(
      index: index,
      totalCount: totalCount,
      isExpanded: expanded,
      onToggle: onToggle,
      header: M3EListItem(
        leading: M3EContainer(
          shape,
          width: 40,
          height: 40,
          color: container,
          child: Icon(_icon, size: 20, color: onContainer),
        ),
        headline: Text(
          entry.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        supportingText: Text('${_clock(entry.time)} · ${entry.kind}'),
      ),
      childCount: 1,
      childBuilder: (context, _) => _details(context),
    );
  }

  IconData get _icon => switch (entry) {
    LogEntry(severity: LogSeverity.error) => Icons.error_outline_rounded,
    LogEntry(kind: 'PeerAdded') => Icons.person_add_alt_rounded,
    LogEntry(kind: 'PeerRemoved') => Icons.person_remove_alt_1_rounded,
    LogEntry(kind: 'PeerConnAdded') => Icons.link_rounded,
    LogEntry(kind: 'PeerConnRemoved') => Icons.link_off_rounded,
    LogEntry(category: LogCategory.listener) => Icons.sensors_rounded,
    LogEntry(category: LogCategory.connection) => Icons.sync_alt_rounded,
    _ => Icons.info_outline_rounded,
  };

  static String _clock(DateTime? time) {
    if (time == null) return '--:--:--';
    final local = time.toLocal();
    String two(int value) => '$value'.padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
        '.${'${local.millisecond}'.padLeft(3, '0')}';
  }

  Widget _details(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final variant = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (key, value) in entry.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key,
                            style: textTheme.labelSmall?.copyWith(
                              color: variant,
                            ),
                          ),
                          Text(
                            value,
                            style: textTheme.bodySmall?.merge(_monospace),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy as JSON',
            onPressed: () => Clipboard.setData(ClipboardData(text: entry.raw)),
            icon: const Icon(Icons.content_copy_rounded),
          ),
        ],
      ),
    );
  }
}

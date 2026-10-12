import 'package:flutter/rendering.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/log_entry.dart';
import 'log_entry_tile.dart';

/// Log entries, newest first, that keep the entries in view still while
/// newer ones arrive, unless the newest entry is the one being viewed.
class LogEntryList extends StatefulWidget {
  const LogEntryList({
    super.key,
    required this.entries,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<LogEntry> entries;
  final bool Function(LogEntry entry) isExpanded;
  final ValueChanged<LogEntry> onToggle;

  @override
  State<LogEntryList> createState() => _LogEntryListState();
}

class _LogEntryListState extends State<LogEntryList> {
  final _scroll = ScrollController();
  final _center = UniqueKey();
  final _showBackToTop = ValueNotifier(false);

  /// The entry at scroll offset zero. Newer entries are laid out above it,
  /// in the negative scroll extent, so they never push the viewed ones away.
  LogEntry? _anchor;

  bool get _atTop =>
      !_scroll.hasClients ||
      _scroll.position.pixels <= _scroll.position.minScrollExtent + 1;

  /// Whether the user took over the scroll since [_backToTop] started.
  bool _userScrolled = false;

  bool _onMetrics(ScrollMetrics metrics) {
    _showBackToTop.value =
        metrics.pixels - metrics.minScrollExtent > metrics.viewportDimension;
    return false;
  }

  Future<void> _backToTop() async {
    _userScrolled = false;
    await _scroll.animateTo(
      _scroll.position.minScrollExtent,
      duration: Durations.long2,
      curve: Easing.emphasizedDecelerate,
    );
    if (!mounted || _userScrolled) return;
    // Entries above the anchor are only estimated until laid out, so the
    // animation may stop short. Anchor on the newest entry to land exactly.
    setState(() => _anchor = widget.entries.firstOrNull);
    _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _showBackToTop.dispose();
    super.dispose();
  }

  Widget _tile(int index) {
    final entry = widget.entries[index];
    return LogEntryTile(
      key: ObjectKey(entry),
      entry: entry,
      index: index,
      totalCount: widget.entries.length,
      expanded: widget.isExpanded(entry),
      onToggle: () => widget.onToggle(entry),
    );
  }

  int _indexOf(Key key) =>
      widget.entries.indexOf((key as ObjectKey).value as LogEntry);

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    var anchor = _anchor == null ? -1 : entries.indexOf(_anchor!);
    // Follow the newest entry while it is in view, or when the anchor is gone.
    if (anchor == -1 || (anchor > 0 && _atTop)) {
      _anchor = entries.firstOrNull;
      anchor = 0;
      if (_scroll.hasClients) _scroll.position.correctPixels(0);
    }

    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) => _onMetrics(notification.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification &&
                  notification.direction != ScrollDirection.idle) {
                _userScrolled = true;
              }
              return _onMetrics(notification.metrics);
            },
            child: CustomScrollView(
              controller: _scroll,
              center: _center,
              slivers: [
                // Grows upwards from the anchor, so it lists newest last.
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _tile(anchor - 1 - index),
                      childCount: anchor,
                      findChildIndexCallback: (key) {
                        final index = _indexOf(key);
                        return index < 0 || index >= anchor
                            ? null
                            : anchor - 1 - index;
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  key: _center,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _tile(anchor + index),
                      childCount: entries.length - anchor,
                      findChildIndexCallback: (key) {
                        final index = _indexOf(key);
                        return index < anchor ? null : index - anchor;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder(
            valueListenable: _showBackToTop,
            builder: (context, show, child) => AnimatedScale(
              scale: show ? 1 : 0,
              duration: Durations.medium2,
              curve: show
                  ? Easing.emphasizedDecelerate
                  : Easing.emphasizedAccelerate,
              child: IgnorePointer(ignoring: !show, child: child),
            ),
            child: M3EFab(
              size: M3EFabSize.small,
              color: M3EFabColor.secondary,
              tooltip: 'Back to top',
              onPressed: _backToTop,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// Hosts the shell's top pages in a [PageView] and keeps them mounted.
///
/// The pages always sit side by side horizontally: a page change made outside
/// the widget slides to the new page, or jumps when transitions are off, and a
/// page the user swiped to is reported through [onPageChanged]. The widget is
/// UI-only.
class TopPageView extends StatefulWidget {
  const TopPageView({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.swipeEnabled,
    required this.transitionsEnabled,
    required this.onPageChanged,
  });

  /// The index of the page that must be shown.
  final int currentIndex;

  /// The top pages, one per destination, in destination order.
  final List<Widget> pages;

  /// Whether a horizontal drag may change the page; callers disable it on the
  /// wide layout and while a nested page is shown.
  final bool swipeEnabled;

  /// Whether page switches slide; when off they jump and no swipe is taken.
  final bool transitionsEnabled;

  /// Reports the page the user swiped to.
  final ValueChanged<int> onPageChanged;

  @override
  State<TopPageView> createState() => _TopPageViewState();
}

class _TopPageViewState extends State<TopPageView> {
  static const Duration _switchDuration = Duration(milliseconds: 300);

  late final PageController _pageController = PageController(
    initialPage: widget.currentIndex,
  );

  /// The page an outside switch is animating to; its intermediate pages are
  /// not pages the user picked.
  int? _animatingTo;

  /// Whether a drag may change the page.
  bool get _swipingAllowed => widget.swipeEnabled && widget.transitionsEnabled;

  @override
  void didUpdateWidget(TopPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _showPage(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showPage(int index) {
    if (!_pageController.hasClients) return;
    if ((_pageController.page ?? index.toDouble()).round() == index) return;
    if (!widget.transitionsEnabled) {
      _pageController.jumpToPage(index);
      return;
    }
    final int target = index;
    _animatingTo = target;
    _pageController
        .animateToPage(
          target,
          duration: _switchDuration,
          curve: Curves.easeInOutCubicEmphasized,
        )
        .whenComplete(() {
          if (_animatingTo != target) return;
          _animatingTo = null;
          final page = _pageController.hasClients ? _pageController.page : null;
          if (page != null && page.round() != widget.currentIndex) {
            widget.onPageChanged(page.round());
          }
        });
  }

  void _onPageChanged(int index) {
    if (_animatingTo == null && index != widget.currentIndex) {
      widget.onPageChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: _swipingAllowed ? null : const NeverScrollableScrollPhysics(),
      onPageChanged: _onPageChanged,
      children: [for (final page in widget.pages) _ShellPage(child: page)],
    );
  }
}

/// One page of the shell, pinned in the tree while another page is shown.
///
/// [PageView] would otherwise dispose a page that scrolls out of the viewport,
/// losing the branch navigator's state. The page also gets its own
/// [ScaffoldMessenger], so a floating snackbar is placed above the page's FAB
/// and the navigation bar instead of covering them.
class _ShellPage extends StatefulWidget {
  const _ShellPage({required this.child});

  final Widget child;

  @override
  State<_ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<_ShellPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldMessenger(child: widget.child);
  }
}

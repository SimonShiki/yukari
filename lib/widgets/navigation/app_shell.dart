import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/l10n.dart';
import 'top_page_view.dart';

/// The shell that hosts the top pages and the destination bar or rail.
///
/// The pages live in a [TopPageView] and every visited page stays mounted so
/// its state and navigation stack survive the switch. Only the compact layout
/// swipes between pages, horizontally; the wide layout changes pages by
/// destination only. [transitions] turns the swipe and the slide off. The
/// shell is UI-only.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.onDestinationSelected,
    required this.transitions,
    this.swipeEnabled = true,
  });

  /// The index of the visible page, mirrored by the destination bar or rail.
  final int currentIndex;

  /// The top pages, one per destination, in destination order.
  final List<Widget> pages;

  /// Reports the destination index the user picked by tapping or swiping.
  final ValueChanged<int> onDestinationSelected;

  /// Whether top pages follow a swipe and slide when switched.
  final ReadonlySignal<bool> transitions;

  /// Whether a drag may change the page; callers disable it off top pages.
  final bool swipeEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<(IconData, IconData, String)> destinations = [
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.hub_outlined, Icons.hub, l10n.navNetworks),
      (Icons.bookmark_outline, Icons.bookmark, l10n.navBookmarks),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    final bool useRail = MediaQuery.sizeOf(context).width >= 600;
    // Only the paging area follows the switch: the destinations never change.
    final pageView = SignalBuilder(
      builder: (context) => TopPageView(
        currentIndex: currentIndex,
        pages: pages,
        // The wide layout has no switch gesture; taps still slide.
        swipeEnabled: swipeEnabled && !useRail,
        transitionsEnabled: transitions.value,
        onPageChanged: onDestinationSelected,
      ),
    );

    return Scaffold(
      // The paging area keeps the same keyed slot in both layouts, so crossing
      // the breakpoint keeps the pages mounted.
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selectedIcon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selectedIcon),
                    label: Text(label),
                  ),
              ],
            ),
          Expanded(key: const ValueKey('top-pages'), child: pageView),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final (icon, selectedIcon, label) in destinations)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selectedIcon),
                    label: label,
                  ),
              ],
            ),
    );
  }
}
